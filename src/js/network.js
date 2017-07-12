const shell = require("shelljs");

shell.config.verbose = false;
shell.config.silent = true;

module.exports = (config, dataCallback, _setInterval = setInterval) => {
  return {
    createProjectNet: () => {
      // check if network already exists
      if (
        shell.exec(`docker network inspect ${config.network.name}`).code != 0
      ) {
        // if network does not exist - create it
        const netCreateCmd =
          "docker network create -d macvlan --subnet=192.168.10.0/24 --gateway=192.168.10.1 -o parent=" +
          config.network.parentNic +
          " " +
          config.network.name;
        const res = shell.exec(netCreateCmd);
        if (res.code != 0) {
          console.error("Could not create macvlan network.", res.stderr);
          process.exit(1);
        }
      }
    },
    scan: () => {
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
    }
  };
};
