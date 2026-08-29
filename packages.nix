{ pkgs }:
let
  inherit (pkgs) lib;

  backendSrc = lib.fileset.toSource {
    root = ./backend/server;
    fileset = lib.fileset.gitTracked ./backend/server;
  };
  frontendSrc = lib.fileset.toSource {
    root = ./frontend;
    fileset = lib.fileset.gitTracked ./frontend;
  };

  python = pkgs.python3.override {
    self = python;
    packageOverrides = final: prev: {
      django = prev.django.override { withGdal = true; };

      reportlab = final.buildPythonPackage rec {
        pname = "reportlab";
        version = "4.4.10";
        pyproject = true;
        src = pkgs.fetchPypi {
          inherit pname version;
          hash = "sha256-XLuzSsNUYDnQCG3rKTjN7AaxLaPNuDboEyWOszzShIc=";
        };
        build-system = [ final.setuptools ];
        buildInputs = [ (pkgs.freetype.overrideAttrs { dontDisableStatic = true; }) ];
        dependencies = [
          final.charset-normalizer
          final.pillow
        ];
        doCheck = false;
        pythonImportsCheck = [ "reportlab" ];
      };

      slippers = final.buildPythonPackage rec {
        pname = "slippers";
        version = "0.6.3";
        pyproject = true;
        src = pkgs.fetchFromGitHub {
          owner = "timhae";
          repo = "slippers";
          rev = "feature/tharing/update-typeguard";
          hash = "sha256-arc6jFM/K0YH/jDpUP3LAC6LKlQsb7M66MlHzpUxRCE=";
        };
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail 'version = "0.7.0"' 'version = "${version}"' \
            --replace-fail 'uv_build>=0.10.12,<0.11.0' 'uv_build'
        '';
        doCheck = false;
        build-system = [ final.uv-build ];
        dependencies = [
          final.django
          final.pyyaml
          final.typeguard
          final.typing-extensions
        ];
        pythonImportsCheck = [ "slippers" ];
      };

      django-allauth-ui = final.buildPythonPackage rec {
        pname = "django_allauth_ui";
        version = "1.8.1";
        pyproject = true;
        src = pkgs.fetchPypi {
          inherit pname version;
          hash = "sha256-WztgfieE/Z+GH/5fRn4N4dGOf5KucEfajybAKrs9ajY=";
        };
        build-system = [ final.poetry-core ];
        dependencies = [
          final.django-widget-tweaks
          final.slippers
        ];
        pythonImportsCheck = [ "allauth_ui" ];
        pythonRelaxDeps = [ "slippers" ];
      };

      django-geojson = final.buildPythonPackage rec {
        pname = "django-geojson";
        version = "4.2.0";
        pyproject = true;
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/c6/94/b7f83ffa37fbc4e8055243a298198858ead93d8d63c7e4c6aeae2b539765/django_geojson-${version}.tar.gz";
          hash = "sha256-HTWiI4TIkWXPxaR8MDO5GLEDW4a9OGJQCgA+k87LeBY=";
        };
        build-system = [ final.setuptools ];
        dependencies = [ final.django ];
        pythonImportsCheck = [ "djgeojson" ];
      };

      django-invitations = final.buildPythonPackage rec {
        pname = "django-invitations";
        version = "2.1.0";
        pyproject = true;
        src = pkgs.fetchFromGitHub {
          owner = "jazzband";
          repo = "django-invitations";
          tag = version;
          hash = "sha256-UfDjiqcv2ewNE+qqczGVooVaCDlIuWBwlE1ybuIcO/8=";
        };
        build-system = [ final.poetry-core ];
        dependencies = [ final.django ];
        pythonImportsCheck = [ "invitations" ];
      };

      django-resized = final.buildPythonPackage rec {
        pname = "django-resized";
        version = "1.0.3";
        pyproject = true;
        src = pkgs.fetchFromGitHub {
          owner = "un1t";
          repo = "django-resized";
          tag = version;
          hash = "sha256-WtZeWOOQdWBOb+IFk2sHoPwTGA+ODGu4gJdq6msQwXM=";
        };
        build-system = [ final.setuptools ];
        dependencies = [
          final.django
          final.pillow
        ];
        checkPhase = "python -m django test --settings=django_resized.tests.settings";
        pythonImportsCheck = [ "django_resized" ];
        env = {
          DJANGORESIZED_DEFAULT_SIZE = "[1920, 1080]";
          DJANGO_SETTINGS_MODULE = "django.conf.global_settings";
        };
      };
    };
  };
  python3Packages = python.pkgs;

  dependencies = with python3Packages; [
    boto3
    coreapi
    cryptography
    django
    django-allauth
    django-allauth-ui
    django-cors-headers
    django-geojson
    django-ical
    django-invitations
    django-money
    django-resized
    django-storages
    django-widget-tweaks
    djangorestframework
    drf-yasg
    fido2
    geojson
    geopy
    gpxpy
    gunicorn
    icalendar
    ijson
    legacy-cgi
    overpy
    pillow
    pillow-heif
    psutil
    psycopg2-binary
    publicsuffix2
    pyjwt
    pymemcache
    python-dotenv
    qrcode
    reportlab
    requests
    setuptools
    slippers
    stripe
    tqdm
    whitenoise
  ];

  geodata = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dr5hn/countries-states-cities-database/v3.1/json/countries%2Bstates%2Bcities.json";
    hash = "sha256-8bJ7X7wRw0GPrr1kpWHfu8fC1GJwMh1Ko7cvDEawFIc=";
  };
  flags = pkgs.runCommand "adventurelog-flags" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    mkdir -p $out/flags
    for flag in ${
      pkgs.fetchFromGitHub {
        owner = "hampusborgos";
        repo = "country-flags";
        rev = "c09927e63705529bbf59ca6684cd9b23225dddad";
        hash = "sha256-O124CG4N76kzB5jiolKEPg13gbyNuu8lh3g0zIilT68=";
      }
    }/svg/*.svg; do
      code="$(basename "$flag" .svg)"
      rsvg-convert --height 240 --keep-aspect-ratio "$flag" --output "$out/flags/$code.png"
    done
  '';

  adventurelog-backend = python3Packages.buildPythonApplication {
    pname = "adventurelog-backend";
    version = "0.13.0";
    src = backendSrc;
    inherit dependencies;
    pyproject = true;
    build-system = [ python3Packages.hatchling ];
    pythonRelaxDeps = [ "slippers" ];
    doCheck = true;
    checkPhase = ''
      export DJANGO_SETTINGS_MODULE=main.settings
      export SECRET_KEY=nix-build-check
      export PGDATABASE=adventurelog
      export PGUSER=adventurelog
      export PGPASSWORD=adventurelog
      export STATIC_ROOT="$TMPDIR/static"
      export MEDIA_ROOT="$TMPDIR/media"

      ${python.interpreter} manage.py check
      ${python.interpreter} - <<'PY'
      import boto3
      import django
      import pillow_heif
      import reportlab
      import stripe
      import storages

      django.setup()
      from adventures.services.collection_pdf import build_collection_pdf
      PY
    '';
    postBuild = ''
      ${python.pythonOnBuildForHost.interpreter} manage.py collectstatic --noinput --verbosity 2
    '';
    postInstall = ''
      mkdir -p $out/bin $out/media
      chmod +x $out/${python3Packages.python.sitePackages}/manage.py
      makeWrapper $out/${python3Packages.python.sitePackages}/manage.py $out/bin/adventurelog-backend \
        --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}:$PYTHONPATH"
      cp -r staticfiles $out/staticfiles
      cp ${geodata} $out/media/countries+regions+states-v3.1.json
      cp -r ${flags}/flags $out/media
    '';
    passthru.dependencyVersions = builtins.listToAttrs (
      map (package: {
        name = lib.toLower (builtins.replaceStrings [ "_" ] [ "-" ] package.pname);
        value = package.version;
      }) dependencies
    );
  };

  adventurelog-frontend = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "adventurelog-frontend";
    version = "0.13.0";
    src = frontendSrc;
    nativeBuildInputs = with pkgs; [
      nodejs_22
      pnpmConfigHook
      pnpm_10
    ];
    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 3;
      pnpm = pkgs.pnpm_10;
      hash = "sha256-Vqge3X+1SHnt5A8obN/WT3kvVbssAMOlPbCBJ+jHyjo=";
    };
    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      pnpm prune --prod --ignore-scripts
      mkdir -p $out
      cp -r build node_modules package.json $out/
      runHook postInstall
    '';
  });
in
{
  inherit
    adventurelog-backend
    adventurelog-frontend
    flags
    geodata
    ;
  inherit (python3Packages)
    django-allauth-ui
    django-geojson
    django-invitations
    django-resized
    reportlab
    slippers
    ;
  adventurelog-python-env = python.withPackages (_: dependencies);
}
