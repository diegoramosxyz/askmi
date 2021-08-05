const chai = require('chai')
chai.use(require('chai-as-promised'))
const { expect } = chai

const {
  ethers: { utils, getSigners, getContractFactory, constants },
} = require('hardhat')

describe('AskMiUltimate', () => {
  // https://docs.ethers.io/v5/api/utils/display-logic/#utils-parseUnits
  function parseEth(amount) {
    return utils.parseEther(amount).toString()
  }
  function parseDai(amount) {
    return utils.parseUnits(amount, 18).toString()
  }

  let accounts
  let daiAddress
  let functionsAddress

  before(async () => {
    accounts = await getSigners()

    // Deploy ERC20
    daiFactory = await getContractFactory('contracts/ERC20.sol:MyToken')
    dai = await daiFactory.deploy('DAI', 'DAI')
    daiAddress = (await dai).address

    // Transfer DAI to second account
    await dai.transfer(accounts[1].address, parseDai('1000.0'))

    // Deploy askmi
    askmiFunctionsFactory = await getContractFactory(
      'contracts/askmi-ultimate/askmi-functions.sol:AskMiFunctions'
    )

    askmiFunctions = await askmiFunctionsFactory.deploy()
    functionsAddress = (await askmiFunctions).address

    // Deploy askmi
    askmiFactory = await getContractFactory(
      'contracts/askmi-ultimate/askmi.sol:AskMi'
    )

    askmi = await askmiFactory.deploy(
      accounts[1].address, //dev
      accounts[0].address //owner
    )

    // Approve ERC20 spending
    await dai
      .connect(accounts[1])
      .approve((await askmi).address, parseDai('1000.0'))
  })

  it('has all correct initial values', async () => {
    let fee = await askmi.fee()
    let questioners = await askmi.getQuestioners()
    let tiers = await askmi.getTiers(constants.AddressZero)
    let owner = await askmi.owner()

    expect(fee).eq('200')
    expect(tiers.length).eq(0)
    expect(questioners[0]).eq(constants.AddressZero)
    expect(owner).eq(accounts[0].address)
  })

  it('supportedTokens() returns no tokens', async () => {
    let supportedTokens = await askmi.getSupportedTokens()
    expect(supportedTokens.length).eq(0)
  })

  it('ask() fails because ETH is not supported', async () => {
    await expect(
      askmi
        .connect(accounts[1])
        .ask(
          functionsAddress,
          constants.AddressZero,
          '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
          '0x12',
          '0x20',
          1,
          { value: utils.parseEther('0') }
        )
    ).to.be.rejected

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(0)
  })

  it('ask() fails because ERC20 is not supported', async () => {
    await expect(
      askmi
        .connect(accounts[1])
        .ask(
          functionsAddress,
          daiAddress,
          '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
          '0x12',
          '0x20',
          1
        )
    ).to.be.rejected

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(0)
  })

  it('updateTiers() adds support for ETH', async () => {
    await askmi.updateTiers(functionsAddress, constants.AddressZero, [
      parseEth('0.01'),
      parseEth('1.0'),
    ])

    let tiers = await askmi.getTiers(constants.AddressZero)

    expect(tiers.length).eq(2)
  })

  it('updateTiers() adds support for ERC20', async () => {
    await askmi.updateTiers(functionsAddress, daiAddress, [
      parseDai('1.0'),
      parseDai('10.0'),
      parseDai('25.0'),
    ])

    tiers = await askmi.getTiers(daiAddress)

    expect(tiers.length).eq(3)
  })

  it('supportedTokens() returns tokens', async () => {
    let supportedTokens = await askmi.getSupportedTokens()

    expect(supportedTokens[0]).eq(constants.AddressZero)
    expect(supportedTokens[1]).eq(daiAddress)
    expect(supportedTokens.length).eq(2)
  })

  it('ask() works for ETH', async () => {
    await askmi
      .connect(accounts[1])
      .ask(
        functionsAddress,
        constants.AddressZero,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1,
        { value: utils.parseEther('1.0') }
      )

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('ask() works for ERC20', async () => {
    await askmi
      .connect(accounts[1])
      .ask(
        functionsAddress,
        daiAddress,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1
      )

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(2)
  })

  it('remove() works with ETH', async () => {
    await askmi
      .connect(accounts[1])
      .remove(functionsAddress, accounts[1].address, 0)

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('remove() works with ERC20', async () => {
    await askmi
      .connect(accounts[1])
      .remove(functionsAddress, accounts[1].address, 0)

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(0)
  })

  it('respond() works with ETH and event is emitted', async () => {
    await askmi
      .connect(accounts[1])
      .ask(
        functionsAddress,
        constants.AddressZero,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1,
        { value: utils.parseEther('1.0') }
      )

    let { wait } = await askmi
      .connect(accounts[0])
      .respond(
        functionsAddress,
        accounts[1].address,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        0
      )

    let { events } = await wait()

    expect(events[0]['event']).eq('QuestionAnswered')

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('respond() works with ERC20 and event is emitted', async () => {
    await askmi
      .connect(accounts[1])
      .ask(
        functionsAddress,
        daiAddress,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1
      )

    let { wait } = await askmi
      .connect(accounts[0])
      .respond(
        functionsAddress,
        accounts[1].address,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1
      )

    let { events } = await wait()

    expect(events[2]['event']).eq('QuestionAnswered')

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(2)
  })

  it('updateTip() works for ETH', async () => {
    await askmi.updateTip(
      functionsAddress,
      parseEth('0.1'),
      constants.AddressZero
    )

    let tip = await askmi.getTip()

    expect(tip[0].toString()).eq(parseEth('0.1'))
    expect(tip[1]).eq(constants.AddressZero)
  })

  it('issueTip() works for ETH', async () => {
    await askmi
      .connect(accounts[1])
      .issueTip(functionsAddress, accounts[1].address, 0, {
        value: utils.parseEther('0.1'),
      })

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions[0].tips.toString()).eq('1')
  })

  it('updateTip() works for ERC20', async () => {
    await askmi.updateTip(functionsAddress, parseEth('0.1'), daiAddress)

    let tip = await askmi.getTip()

    expect(tip[0].toString()).eq(parseEth('0.1'))
    expect(tip[1]).eq(daiAddress)
  })

  it('issueTip() works for ERC20', async () => {
    await askmi
      .connect(accounts[1])
      .issueTip(functionsAddress, accounts[1].address, 1)

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions[1].tips.toString()).eq('1')
  })

  it('updateTiers() drops support for ETH', async () => {
    await askmi.updateTiers(functionsAddress, constants.AddressZero, [])

    let tiers = await askmi.getTiers(constants.AddressZero)
    expect(tiers.length).eq(0)

    supportedTokens = await askmi.getSupportedTokens()
    expect(supportedTokens[0]).eq(daiAddress)
    expect(supportedTokens.length).eq(1)
  })

  it('updateTiers() drops support for ERC20', async () => {
    await askmi.updateTiers(functionsAddress, daiAddress, [])

    let tiers = await askmi.getTiers(daiAddress)

    expect(tiers.length).eq(0)

    let supportedTokens = await askmi.getSupportedTokens()

    expect(supportedTokens.length).eq(0)
  })

  it('toggleDisabled() works', async () => {
    await askmi.updateTiers(functionsAddress, constants.AddressZero, [
      parseEth('1.0'),
    ])

    await askmi.toggleDisabled(functionsAddress)

    await expect(
      askmi
        .connect(accounts[1])
        .ask(
          functionsAddress,
          constants.AddressZero,
          '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
          '0x12',
          '0x20',
          0,
          { value: utils.parseEther('1.0') }
        )
    ).to.be.rejected

    await askmi.toggleDisabled(functionsAddress)

    await askmi
      .connect(accounts[1])
      .ask(
        functionsAddress,
        constants.AddressZero,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        0,
        { value: utils.parseEther('1.0') }
      )
  })
})
