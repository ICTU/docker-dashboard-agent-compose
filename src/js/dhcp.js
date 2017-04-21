
module.exports = (config, dataCallback, _setInterval=setInterval) => {
  const getDhcpStats = () => {
    // console.log('dhcp');
  }
  getDhcpStats()
  _setInterval(getDhcpStats, config.dhcp.scanInterval)
}
