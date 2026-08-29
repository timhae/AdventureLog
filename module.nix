{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.adventurelog;
  format = pkgs.formats.keyValue { };
  varLibStateDir = "/var/lib/${cfg.stateDir}";
  backendEnvironment = cfg.backendEnvironment // {
    CACHE_LOCATION = "${cfg.cache.host}:${toString cfg.cache.port}";
    PGHOST = cfg.database.host;
    PGPORT = cfg.database.port;
    PGDATABASE = cfg.database.name;
    PGUSER = cfg.database.user;
  };
  hardening = {
    CapabilityBoundingSet = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateUsers = true;
    ProcSubset = "pid";
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@cpu-emulation"
      "~@debug"
      "~@mount"
      "~@obsolete"
    ];
    MemoryDenyWriteExecute = true;
    UMask = "0027";
  };
in
{
  options.services.adventurelog = {
    enable = lib.mkEnableOption "AdventureLog.";

    frontend = lib.mkPackageOption pkgs "adventurelog-frontend" { };

    backend = lib.mkPackageOption pkgs "adventurelog-backend" { };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "adventurelog";
      description = ''
        Directory to store all stateful configuration, logs and files. Will be
        created as subdirectory of `/var/lib/`.
      '';
    };

    siteUrl = lib.mkOption {
      type = lib.types.str;
      default =
        if cfg.domain != null then
          "${if cfg.nginx.forceSSL || cfg.nginx.enableACME then "https" else "http"}://${cfg.domain}"
        else
          "http://127.0.0.1:${toString cfg.frontendEnvironment.PORT}";
      description = "Public URL where AdventureLog is available.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "adventurelog";
      description = "User account used by the backend service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "adventurelog";
      description = "Group used by the backend service and nginx for protected media.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the configured backend user and group.";
    };

    initializeData = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to import country, region, city, and flag data during initial setup.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional file containing additional non-secret backend environment variables.";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Optional file containing secret backend environment variables in
        systemd EnvironmentFile format, such as `GOOGLE_MAPS_API_KEY`.
        Keep this file outside the Nix store and protect it with appropriate
        file permissions.
      '';
    };

    nginx = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.domain != null;
        description = "Whether to configure nginx as a reverse proxy.";
      };

      enableACME = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to obtain a TLS certificate using ACME.";
      };

      useACMEHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of an existing ACME certificate to use for this virtual host.";
      };

      forceSSL = lib.mkOption {
        type = lib.types.bool;
        default = cfg.nginx.enableACME;
        description = "Whether to redirect HTTP requests to HTTPS.";
      };
    };

    cache = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run a local memcached service.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Memcached server host.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11211;
        description = "Memcached server port.";
      };
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to provision a local PostgreSQL database with PostGIS.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "PostgreSQL server host.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "PostgreSQL server port.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "adventurelog";
        description = "PostgreSQL database name.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "adventure";
        description = "PostgreSQL role used by AdventureLog.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "File containing the PostgreSQL password.";
      };

      package = lib.mkPackageOption pkgs "postgresql_16" { };
    };

    frontendEnvironment = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          PUBLIC_SERVER_URL = lib.mkOption {
            type = lib.types.str;
            default = cfg.backendEnvironment.PUBLIC_URL;
            description = "URL of the backend server.";
          };
          ORIGIN = lib.mkOption {
            type = lib.types.str;
            default = cfg.siteUrl;
            description = "URL of the frontend server.";
          };
          HOST = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Interface the fronted will accept connections on.";
          };
          PORT = lib.mkOption {
            type = lib.types.port;
            default = 8015;
            description = "Port where the frontend server will accept connections from.";
          };
          NODE_ENV = lib.mkOption {
            type = lib.types.str;
            default = "production";
            description = "Node environment.";
          };
          BODY_SIZE_LIMIT = lib.mkOption {
            type = lib.types.str;
            default = "Infinity";
            description = "Maximum upload filesize, restrict this on public servers.";
          };
        };
      };
      default = { };
      description = ''
        Environment variables for the adventurelog app frontend.
        See the [docs](https://adventurelog.app/docs/configuration/analytics.html)
        for available options.

        Also check the Svelte node adapter [docs](https://svelte.dev/docs/kit/adapter-node#Environment-variables).
      '';
    };

    backendEnvironment = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          DJANGO_ADMIN_USERNAME = lib.mkOption {
            type = lib.types.str;
            default = "admin";
            description = "Name of the Django admin user.";
          };
          DJANGO_ADMIN_EMAIL = lib.mkOption {
            type = lib.types.str;
            default = "admin@example.com";
            description = "Email of the Django admin user.";
          };
          PUBLIC_URL = lib.mkOption {
            type = lib.types.str;
            default = "http://${cfg.backendEnvironment.HOST}:${toString cfg.backendEnvironment.PORT}";
            description = "URL of the Django backend, usually served from behind an NGINX.";
          };
          SITE_URL = lib.mkOption {
            type = lib.types.str;
            default = cfg.siteUrl;
            description = "Public URL used for a single-domain deployment.";
          };
          CSRF_TRUSTED_ORIGINS = lib.mkOption {
            type = lib.types.str;
            default = "${cfg.backendEnvironment.SITE_URL},${cfg.backendEnvironment.PUBLIC_URL},http://localhost:8015,http://localhost:8016";
            description = "Allowed URLs.";
          };
          FRONTEND_URL = lib.mkOption {
            type = lib.types.str;
            default = cfg.backendEnvironment.SITE_URL;
            description = "Frontend URL.";
          };
          DEBUG = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable debug output.";
          };
          PYTHONUNBUFFERED = lib.mkOption {
            type = lib.types.str;
            default = "1";
            description = "Don't buffer python output.";
          };
          HOST = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "URL of the backend server.";
          };
          PORT = lib.mkOption {
            type = lib.types.port;
            default = 8016;
            description = "Port of the backend server.";
          };
        };
      };
      default = { };
      description = ''
        Environment variables for the adventurelog app.
        See the [docs](https://adventurelog.app/docs/configuration/immich_integration.html)
        for available options.

        Also check the Django [docs](https://docs.djangoproject.com/en/6.0/ref/settings/).
      '';
    };

    djangoAdminPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        File containing the Django admin password. Secrets should be added in
        environmentFiles instead of `backendEnvironment`.
      '';
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        File containing the Django secret key. Secrets should be added in
        environmentFiles instead of `backendEnvironment`.
      '';
    };

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Domain to host adventurelog with nginx";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = !(cfg.backendEnvironment ? DJANGO_ADMIN_PASSWORD);
        message = ''
          You have defined an admin password using the `backendEnvironment`
          option, which will be ignored. Use the dedicated
          `djangoAdminPasswordFile` option instead.
        '';
      }
      {
        assertion = !(cfg.backendEnvironment ? SECRET_KEY);
        message = ''
          You have defined a secret key using the `backendEnvironment` option,
          which will be ignored. Use the dedicated `secretKeyFile` option instead.
        '';
      }
      {
        assertion = !(cfg.backendEnvironment ? PGPASSWORD);
        message = ''
          You have defined a postgresql password using the `backendEnvironment`
          option, which will be ignored. Use `database.passwordFile` instead.
        '';
      }
      {
        assertion = lib.all (name: !(builtins.hasAttr name cfg.backendEnvironment)) [
          "PGHOST"
          "PGPORT"
          "PGDATABASE"
          "PGUSER"
          "POSTGRES_DB"
          "POSTGRES_USER"
          "POSTGRES_PASSWORD"
        ];
        message = "Database settings must be configured with services.adventurelog.database.";
      }
      {
        assertion = builtins.match "[A-Za-z_][A-Za-z0-9_]*" cfg.database.name != null;
        message = "services.adventurelog.database.name must be a valid PostgreSQL identifier.";
      }
      {
        assertion = builtins.match "[A-Za-z_][A-Za-z0-9_]*" cfg.database.user != null;
        message = "services.adventurelog.database.user must be a valid PostgreSQL identifier.";
      }
      {
        assertion = !cfg.nginx.enable || cfg.domain != null;
        message = "services.adventurelog.domain must be set when nginx is enabled.";
      }
    ];

    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      upstreams.adventurelog-backend.servers = {
        "${cfg.backendEnvironment.HOST}:${toString cfg.backendEnvironment.PORT}" = { };
      };
      upstreams.adventurelog-frontend.servers = {
        "${cfg.frontendEnvironment.HOST}:${toString cfg.frontendEnvironment.PORT}" = { };
      };

      virtualHosts."${cfg.domain}" = {
        inherit (cfg.nginx) enableACME forceSSL useACMEHost;
        extraConfig = ''
          sendfile on;
          keepalive_timeout 65;
          client_max_body_size 100M;
          proxy_buffer_size 32k;
          proxy_buffers 8 32k;
          proxy_busy_buffers_size 64k;
        '';
        locations = {
          "/" = {
            proxyPass = "http://adventurelog-frontend";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
          "~ ^/(media|admin|accounts)(/|$)" = {
            proxyPass = "http://adventurelog-backend";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
          "/protectedMedia/" = {
            alias = "${varLibStateDir}/backend/media/";
            extraConfig = ''
              internal; # Only internal requests are allowed
              try_files $uri =404; # Return a 404 if the file doesn't exist

              # Security headers for all protected files
              add_header Content-Security-Policy "default-src 'self'; script-src 'none'; object-src 'none'; base-uri 'none'" always;
              add_header X-Content-Type-Options nosniff always;
              add_header X-Frame-Options SAMEORIGIN always;
              add_header X-XSS-Protection "1; mode=block" always;
              add_header Referrer-Policy "strict-origin-when-cross-origin" always;
            '';
          };
        };
      };
    };

    services.memcached = lib.mkIf cfg.cache.createLocally {
      enable = true;
      listen = cfg.cache.host;
      port = cfg.cache.port;
    };

    users.groups = lib.mkIf cfg.createUser { ${cfg.group} = { }; };
    users.users = lib.mkMerge [
      (lib.mkIf cfg.createUser {
        ${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
        };
      })
      (lib.mkIf cfg.nginx.enable {
        nginx.extraGroups = [ cfg.group ];
      })
    ];

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      package = cfg.database.package;
      extensions = ps: with ps; [ postgis ];
    };

    documentation.info.enable = false; # whatever this is

    systemd.services = {
      adventurelog-frontend = {
        description = "AdventureLog frontend";
        after = [
          "network.target"
          "adventurelog-backend.service"
        ];
        requires = [
          "network.target"
          "adventurelog-backend.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.nodejs_22} ${cfg.frontend}/build/index.js";
          Restart = "on-failure";
          EnvironmentFile = format.generate "adventurelog-frontend.env" cfg.frontendEnvironment;
          Environment = [
            "HOME=${varLibStateDir}/frontend"
          ];
          WorkingDirectory = "${varLibStateDir}/frontend";
          StateDirectory = "${cfg.stateDir}/frontend";
          DynamicUser = true;
        }
        // hardening
        // {
          # node's V8 JIT needs writable+executable memory
          MemoryDenyWriteExecute = false;
        };
      };

      adventurelog-postgresql-setup = lib.mkIf cfg.database.createLocally {
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        wantedBy = [ "adventurelog-backend.service" ];
        path = [ config.services.postgresql.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          Group = "postgres";
          LoadCredential = [ "db_password:${cfg.database.passwordFile}" ];
        };
        script = ''
          set -o errexit -o pipefail -o nounset -o errtrace
          shopt -s inherit_errexit

          db_password="$(<"$CREDENTIALS_DIRECTORY/db_password")"
          psql --set=db_password="$db_password" <<'SQL'
          SELECT format('CREATE ROLE %I LOGIN', '${cfg.database.user}')
            WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${cfg.database.user}') \gexec
          ALTER ROLE "${cfg.database.user}" WITH LOGIN PASSWORD :'db_password';
          SELECT format('CREATE DATABASE %I OWNER %I', '${cfg.database.name}', '${cfg.database.user}')
            WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${cfg.database.name}') \gexec
          SQL
          psql --dbname="${cfg.database.name}" --command="CREATE EXTENSION IF NOT EXISTS postgis;"
        '';
        enableStrictShellChecks = true;
      };

      adventurelog-backend = {
        description = "AdventureLog backend";
        after = [
          "network.target"
        ]
        ++ lib.optional cfg.cache.createLocally "memcached.service"
        ++ lib.optional cfg.database.createLocally "adventurelog-postgresql-setup.service";
        requires = [
          "network.target"
        ]
        ++ lib.optional cfg.cache.createLocally "memcached.service"
        ++ lib.optional cfg.database.createLocally "adventurelog-postgresql-setup.service";
        wantedBy = [ "multi-user.target" ];
        script = ''
          export DJANGO_ADMIN_PASSWORD="$(<"$CREDENTIALS_DIRECTORY/django_admin_password")"
          export SECRET_KEY="$(<"$CREDENTIALS_DIRECTORY/secret_key")"
          export PGPASSWORD="$(<"$CREDENTIALS_DIRECTORY/pgpassword")"

          mkdir -p "$STATIC_ROOT" "$MEDIA_ROOT"
          cp -rn ${cfg.backend}/staticfiles/. "$STATIC_ROOT/"
          ${cfg.backend}/bin/adventurelog-backend migrate
          cp -rn ${cfg.backend}/media/. "$MEDIA_ROOT/"

          if [ ! -f ~/setup-done ]; then
            if [ -n "$DJANGO_ADMIN_USERNAME" ] && [ -n "$DJANGO_ADMIN_PASSWORD" ] && [ -n "$DJANGO_ADMIN_EMAIL" ]; then
              echo "Creating superuser..."
              ${cfg.backend}/bin/adventurelog-backend shell << EOF
          from django.contrib.auth import get_user_model
          from allauth.account.models import EmailAddress

          User = get_user_model()

          # Check if the user already exists
          if not User.objects.filter(username='$DJANGO_ADMIN_USERNAME').exists():
              # Create the superuser
              superuser = User.objects.create_superuser(
                  username='$DJANGO_ADMIN_USERNAME',
                  email='$DJANGO_ADMIN_EMAIL',
                  password='$DJANGO_ADMIN_PASSWORD'
              )
              print("Superuser created successfully.")

              # Create the EmailAddress object for AllAuth
              EmailAddress.objects.create(
                  user=superuser,
                  email='$DJANGO_ADMIN_EMAIL',
                  verified=True,
                  primary=True
              )
              print("EmailAddress object created successfully for AllAuth.")
          else:
              print("Superuser already exists.")
          EOF
            fi

            ${lib.optionalString cfg.initializeData ''
              # Sync the countries and world travel regions.
              ${cfg.backend}/bin/adventurelog-backend download-countries
            ''}
            echo 1 > ~/setup-done
          fi

          ${lib.getExe pkgs.python3Packages.gunicorn} main.wsgi:application \
            --bind "${cfg.backendEnvironment.HOST}:${toString cfg.backendEnvironment.PORT}" \
            --workers 2 --timeout 120 --pythonpath $PYTHONPATH'';
        serviceConfig = {
          Restart = "on-failure";
          User = cfg.user;
          Group = cfg.group;
          Environment = [
            "PYTHONPATH=${cfg.backend}/${pkgs.python3.sitePackages}:${pkgs.python3Packages.makePythonPath cfg.backend.passthru.dependencies}"
            "MEDIA_ROOT=${varLibStateDir}/backend/media"
            "STATIC_ROOT=${varLibStateDir}/backend/staticfiles"
            "HOME=${varLibStateDir}/backend"
          ];
          EnvironmentFile = [
            (format.generate "adventurelog-backend.env" backendEnvironment)
          ]
          ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile
          ++ lib.optional (cfg.secretsFile != null) cfg.secretsFile;
          LoadCredential = [
            "django_admin_password:${cfg.djangoAdminPasswordFile}"
            "secret_key:${cfg.secretKeyFile}"
            "pgpassword:${cfg.database.passwordFile}"
          ];
          WorkingDirectory = "${varLibStateDir}/backend";
          StateDirectory = "${cfg.stateDir}/backend";
          StateDirectoryMode = "0750";
          ExecStartPost = [
            "${lib.getExe pkgs.curl} --fail --silent --show-error --retry 60 --retry-delay 10 --retry-all-errors --retry-connrefused http://${cfg.backendEnvironment.HOST}:${toString cfg.backendEnvironment.PORT}/health/"
          ];
          TimeoutStartSec = "5min";
        }
        // hardening;
      };
    };
  };
}
