{
  self,
  ...
}:
{
  name = "adventurelog test";
  nodes.machine =
    { config, pkgs, ... }:
    {
      environment.etc = {
        "django".text = "supersecret";
        "key".text = "supersecret";
        "pg".text = "supersecret";
        "adventurelog-secrets".text = "GOOGLE_MAPS_API_KEY=test-google-maps-key";
      };
      imports = [ self.nixosModules.default ];
      virtualisation = {
        memorySize = 4096;
        cores = 4;
      };
      services.adventurelog = {
        enable = true;
        domain = "adventurelog.test";
        djangoAdminPasswordFile = "/etc/django";
        secretKeyFile = "/etc/key";
        database.passwordFile = "/etc/pg";
        secretsFile = "/etc/adventurelog-secrets";
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("memcached.service")
    machine.wait_for_unit("adventurelog-postgresql-setup.service")
    machine.wait_for_unit("adventurelog-backend.service")
    machine.wait_for_unit("adventurelog-frontend.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(8016)
    machine.wait_for_open_port(8015)
    machine.sleep(10)
    machine.succeed("curl --fail http://127.0.0.1:8016/health/")
    machine.succeed("curl --fail http://127.0.0.1:8015/health")
    machine.succeed("curl --fail --silent --show-error --cookie-jar /tmp/adventurelog.cookies --header 'Host: adventurelog.test' --header 'Origin: http://adventurelog.test' --header 'Content-Type: application/x-www-form-urlencoded' --data 'username=admin&password=supersecret' http://127.0.0.1/login")
    machine.succeed("curl --fail --silent --show-error --cookie /tmp/adventurelog.cookies --header 'Host: adventurelog.test' http://127.0.0.1/auth/current-user/")
    machine.succeed("test \"$(curl --silent --show-error --cookie /tmp/adventurelog.cookies --header 'Host: adventurelog.test' --output /dev/null --write-out '%{http_code}' http://127.0.0.1/dashboard)\" = 200")
    machine.succeed("test \"$(systemctl show --property=NRestarts --value adventurelog-backend.service)\" = 0")
    machine.succeed("test \"$(systemctl show --property=NRestarts --value adventurelog-frontend.service)\" = 0")
  '';

  interactive.nodes.machine = {
    networking.firewall.allowedTCPPorts = [ 80 ];
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 8888;
        guest.port = 80;
      }
    ];
  };
}
