// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat')

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // DEPLOY ERC20
  const erc20Factory = await hre.ethers.getContractFactory('MyToken')
  const erc20 = await erc20Factory.deploy('DAI', 'DAI')

  await erc20.deployed()

  console.log('MyToken deployed to:', erc20.address)

  // DEPLOY ASKMI FUNCTIONS
  const askMiFunctionsFactory = await hre.ethers.getContractFactory(
    'AskMiFunctions'
  )
  const askMiFunctions = await askMiFunctionsFactory.deploy()

  await askMiFunctions.deployed()

  console.log('AskMi Functions deployed to:', askMiFunctions.address)

  // DEPLOY ASKMI FACTORY
  const askMiFactoryFactory = await hre.ethers.getContractFactory(
    'AskMiFactory'
  )
  const askMiFactory = await askMiFactoryFactory.deploy()

  await askMiFactory.deployed()

  console.log('AskMi Factory deployed to:', askMiFactory.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
