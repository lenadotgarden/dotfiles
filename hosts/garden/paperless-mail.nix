{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  domain = "docs.lena.sh";
  stateDir = "/var/lib/paperless-mail";
  runDir = "/run/paperless-mail";
  consumeDir = "/var/lib/paperless/consume";
  stagingDir = "/var/lib/paperless/mail-staging";

  # Reçoit un mail sur stdin (Postfix pipe), écrit chaque pièce jointe
  # exploitable dans le dossier d'import de Paperless. Écriture atomique :
  # fichier créé dans stagingDir puis rename() dans consumeDir (même FS).
  ingest = pkgs.writeScript "paperless-mail-ingest" ''
    #!${pkgs.python3}/bin/python3
    import email, os, re, sys, syslog, time, uuid
    from email import policy

    CONSUME = "${consumeDir}"
    STAGING = "${stagingDir}"
    EXT = {".pdf", ".png", ".jpg", ".jpeg", ".tif", ".tiff", ".webp", ".gif", ".txt", ".csv"}
    MAX = 50 * 1024 * 1024

    syslog.openlog("paperless-mail", 0, syslog.LOG_MAIL)
    msg = email.message_from_binary_file(sys.stdin.buffer, policy=policy.default)
    subject = str(msg.get("Subject", ""))[:80]
    sender = str(msg.get("From", ""))[:80]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    saved = 0
    for part in msg.walk():
        if part.is_multipart():
            continue
        name = part.get_filename()
        if not name:
            continue
        name = re.sub(r"[^\w.\- ]", "_", os.path.basename(name)).strip(". ") or "document"
        ext = os.path.splitext(name)[1].lower()
        data = part.get_payload(decode=True) or b""
        if ext not in EXT or not data or len(data) > MAX:
            syslog.syslog(syslog.LOG_INFO, "ignored attachment %r (ext=%s size=%d)" % (name, ext, len(data)))
            continue
        tmp = os.path.join(STAGING, uuid.uuid4().hex)
        with open(tmp, "wb") as f:
            f.write(data)
        os.rename(tmp, os.path.join(CONSUME, "mail-%s-%d-%s" % (stamp, saved, name)))
        saved += 1
    syslog.syslog(syslog.LOG_INFO, "from=%r subject=%r saved=%d" % (sender, subject, saved))
    sys.exit(0)
  '';
in
{
  ############################################################
  # Réception de mails -> Paperless. Postfix minimal, RÉCEPTION SEULE :
  #  - une seule adresse acceptée (localpart aléatoire dans sops, non devinable) ;
  #    tout le reste est refusé dès le SMTP (pas de rebond, pas de spam stocké) ;
  #  - aucun relais, aucun envoi ;
  #  - chaque pièce jointe pdf/image/txt/csv est déposée dans le dossier
  #    d'import de Paperless (pas de corps de mail, pas de boîte à maintenir) ;
  #  - STARTTLS opportuniste avec certificat auto-signé (généré une fois).
  # Domaine de réception : docs.lena.sh (MX dédié), le MX de lena.sh
  # (transfert Spaceship) n'est pas touché.
  ############################################################
  sops.secrets."paperless/mail_inbox" = { owner = "root"; mode = "0400"; };

  networking.firewall.allowedTCPPorts = [ 25 ];

  services.postfix = {
    enable = true;
    enableSmtp = true;
    setSendmail = false;
    settings.main = {
      myhostname = domain;
      mydestination = "";
      mynetworks = [ "127.0.0.0/8" ];
      inet_interfaces = "all";
      inet_protocols = "ipv4";
      virtual_mailbox_domains = domain;
      virtual_mailbox_maps = "texthash:${runDir}/recipients";
      virtual_transport = "paperless-ingest";
      "paperless-ingest_destination_recipient_limit" = 1;
      message_size_limit = 52428800;
      smtpd_helo_required = true;
      disable_vrfy_command = true;
      smtpd_relay_restrictions = [ "reject_unauth_destination" ];
      smtpd_recipient_restrictions = [
        "reject_non_fqdn_recipient"
        "reject_unknown_sender_domain"
        "reject_unauth_destination"
      ];
      smtpd_client_connection_rate_limit = 20;
      smtpd_client_message_rate_limit = 20;
      smtpd_tls_security_level = "may";
      smtpd_tls_chain_files = [ "${stateDir}/tls/key.pem" "${stateDir}/tls/cert.pem" ];
    };
    settings.master.paperless-ingest = {
      type = "unix";
      chroot = false;
      maxproc = 2;
      command = "pipe";
      args = [ "flags=Rq" "user=paperless:paperless" "argv=${ingest}" ];
    };
  };

  # Génère (au démarrage) la table des destinataires depuis sops et, une
  # seule fois, le certificat TLS auto-signé.
  systemd.services.paperless-mail-prepare = {
    description = "Prépare Postfix (destinataire sops + certificat) pour Paperless";
    before = [ "postfix.service" ];
    requiredBy = [ "postfix.service" ];
    path = [ pkgs.openssl pkgs.coreutils ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      install -d -m 0755 ${runDir}
      lp=$(tr -d '[:space:]' < ${s."paperless/mail_inbox".path})
      printf '%s@${domain} OK\n' "$lp" > ${runDir}/recipients
      chmod 0644 ${runDir}/recipients
      if [ ! -s ${stateDir}/tls/cert.pem ]; then
        install -d -m 0700 ${stateDir}/tls
        openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
          -subj "/CN=${domain}" \
          -keyout ${stateDir}/tls/key.pem -out ${stateDir}/tls/cert.pem
        chmod 0600 ${stateDir}/tls/key.pem
      fi
    '';
  };
  systemd.services.postfix.requires = [ "paperless-mail-prepare.service" ];
  systemd.services.postfix.after = [ "paperless-mail-prepare.service" ];

  systemd.tmpfiles.rules = [
    "d ${stagingDir} 0750 paperless paperless -"
  ];
}
