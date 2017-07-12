td = require("testdouble");

var shelljs, network;

conf = {
  network: {
    scanCmd: "nmap -sP -n 10.25.181.51-240",
    scanInterval: 1234
  }
};

describe("network", () => {
  afterEach(() => {
    td.reset();
  });

  beforeEach(() => {
    shell = td.replace("shelljs");
    shell.exec = td.function();
    network = require("../../src/js/network");
  });

  it("should perform an nmap scan and publish the data through the callback", () => {
    _setInterval = td.function();
    cb = td.function();
    stdout = "Nmap done: 200\n\n56 hosts up";
    td
      .when(shell.exec("nmap -sP -n 10.25.181.51-240"))
      .thenReturn({ code: 0, stdout: stdout });
    network(conf, cb, _setInterval).scan();
    td.verify(
      cb({
        totalIps: 200,
        usedIps: 56
      })
    );
    td.verify(_setInterval(td.matchers.anything(), 1234));
  });
});
