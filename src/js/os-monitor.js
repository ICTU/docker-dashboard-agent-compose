const monitor = require("os-monitor")

module.exports = (publishSystemMemInfo, publishSystemUptime, publishSystemCpu) => {
  monitor.start({delay:10000})

  const cpus = monitor.os.cpus()

  monitor.on('monitor', (event) => {
    console.log('monitor!', event);
    console.log(monitor.os.cpus());
    publishSystemMemInfo({
      free: event.freemem,
      total: event.totalmem
    })
    publishSystemUptime(event.uptime)
    publishSystemCpu({
      loadavg: {
        '1min': event.loadavg[0],
        '5min': event.loadavg[1],
        '15min': event.loadavg[2],
      },
      cpus: {
        count: cpus.length,
        model: cpus[0].model
      }
    })
  })
}
