require('@nomiclabs/hardhat-waffle')
require('dotenv').config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

// const { MUMBAI_API_URL, ROPSTEN_API_URL, PRIVATE_KEY } = process.env

/**
 * Hardhat Localhost network (MetaMask)
 * Network Name: HardHat
 * RPC URL: http://localhost:8545
 * Chain ID: 31337
 * Currency Symbol: ETH
 * Block Explorer URL: <LEAVE BLANK>
 */

module.exports = {
  solidity: '0.8.0',
  // defaultNetwork: 'ropsten',
  networks: {
    // hardhat: {},
    // ropsten: {
    //   url: ROPSTEN_API_URL,
    //   accounts: [`0x${PRIVATE_KEY}`],
    // },
    // mumbai: {
    //   url: MUMBAI_API_URL,
    //   accounts: [`0x${PRIVATE_KEY}`],
    // },
  },
}
