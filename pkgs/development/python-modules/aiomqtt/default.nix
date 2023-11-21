{ lib
, anyio
, buildPythonPackage
, fetchFromGitHub
, paho-mqtt
, poetry-core
, poetry-dynamic-versioning
, pytestCheckHook
, pythonOlder
, typing-extensions
}:

buildPythonPackage rec {
  pname = "aiomqtt";
  version = "1.2.1";
  format = "pyproject";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "sbtinstruments";
    repo = "aiomqtt";
    rev = "refs/tags/v${version}";
    hash = "sha256-P8p21wjmFDvI0iobpQsWkKYleY4M0R3yod3/mJ7V+Og=";
  };

  nativeBuildInputs = [
    poetry-core
    poetry-dynamic-versioning
  ];

  propagatedBuildInputs = [
    paho-mqtt
    typing-extensions
  ];

  nativeCheckInputs = [
    anyio
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "aiomqtt"
  ];

  pytestFlagsArray = [
    "-m" "'not network'"
  ];

  meta = with lib; {
    description = "The idiomatic asyncio MQTT client, wrapped around paho-mqtt";
    homepage = "https://github.com/sbtinstruments/aiomqtt";
    changelog = "https://github.com/sbtinstruments/aiomqtt/blob/${version}/CHANGELOG.md";
    license = licenses.bsd3;
    maintainers = with maintainers; [ ];
  };
}
