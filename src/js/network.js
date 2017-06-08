const shell = require("shelljs");

shell.config.verbose = false;
shell.config.silent = true;

module.exports = (config, dataCallback, _setInterval = setInterval) => {
  const getNetStats = () => {
    console.log(`Perfom: ${config.network.scanCmd}`);
    res = shell.exec(config.network.scanCmd);
    if (res.code == 0) {
      totalIps = res.stdout.match(/Nmap done: ?(\d+)/);
      usedIps = res.stdout.match(/(\d+) hosts up/);
      dataCallback({
        totalIps: parseInt(totalIps[1]),
        usedIps: parseInt(usedIps[1])
      });
    } else {
      console.error("nmap probe failed", res.stderr);
    }
  };
  getNetStats();
  _setInterval(getNetStats, config.network.scanInterval);
};
