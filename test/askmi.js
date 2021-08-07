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
    daiFactory = await getContractFactory('MyToken')
    dai = await daiFactory.deploy('DAI', 'DAI')
    daiAddress = (await dai).address

    // Transfer DAI to second account
    await dai.transfer(accounts[1].address, parseDai('1000.0'))

    // Deploy askmi functions
    askmiFunctionsFactory = await getContractFactory('AskMiFunctions')

    askmiFunctions = await askmiFunctionsFactory.deploy()
    functionsAddress = (await askmiFunctions).address

    // Deploy askmi factory
    AskMiFactoryFactory = await getContractFactory('AskMiFactory')

    AskMiFactory = await AskMiFactoryFactory.deploy()

    let tx = await AskMiFactory.instantiateAskMi(
      constants.AddressZero,
      constants.AddressZero,
      [parseEth('0.1'), parseEth('10.0')],
      parseEth('0.1'),
      100
    )

    expect((await tx.wait()).events[0].args.length).eq(1)

    // Deploy askmi
    askmiF = await getContractFactory('AskMi')

    askmi = await askmiF.deploy(
      accounts[1].address, //dev
      accounts[0].address, //owner
      constants.AddressZero,
      constants.AddressZero,
      [parseEth('0.1'), parseEth('10.0')],
      parseEth('0.1'),
      100 // (balance/100 = 1%)
    )

    // Approve ERC20 spending
    await dai
      .connect(accounts[1])
      .approve((await askmi).address, parseDai('1000.0'))
  })

  it('has all correct initial values', async () => {
    let fees = await askmi._fees()
    let tip = await askmi._tip()
    let questioners = await askmi.questioners()
    let tiers = await askmi.getTiers(constants.AddressZero)
    let owner = await askmi._owner()

    expect(fees.developer).eq('200')
    expect(fees.removal).eq('100')
    expect(tiers.length).eq(2)
    expect(questioners[0]).eq(constants.AddressZero)
    expect(tip[0]).eq(constants.AddressZero)
    expect(owner).eq(accounts[0].address)
  })

  it('supportedTokens() returns no tokens', async () => {
    let supportedTokens = await askmi.supportedTokens()
    expect(supportedTokens.length).eq(1)
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
    let supportedTokens = await askmi.supportedTokens()

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

    questions = await askmi.questions(accounts[1].address)

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

    questions = await askmi.questions(accounts[1].address)

    expect(questions.length).eq(2)
  })

  it('remove() works with ETH', async () => {
    await askmi
      .connect(accounts[1])
      .remove(functionsAddress, accounts[1].address, 0)

    let questions = await askmi.questions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('remove() works with ERC20', async () => {
    await askmi
      .connect(accounts[1])
      .remove(functionsAddress, accounts[1].address, 0)

    let questions = await askmi.questions(accounts[1].address)

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

    let questions = await askmi.questions(accounts[1].address)

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

    let questions = await askmi.questions(accounts[1].address)

    expect(questions.length).eq(2)
  })

  it('updateTip() works for ETH', async () => {
    await askmi.updateTip(
      functionsAddress,
      parseEth('0.1'),
      constants.AddressZero
    )

    let tip = await askmi._tip()

    expect(tip[0]).eq(constants.AddressZero)
    expect(tip[1].toString()).eq(parseEth('0.1'))
  })

  it('issueTip() works for ETH', async () => {
    await askmi
      .connect(accounts[1])
      .issueTip(functionsAddress, accounts[1].address, 0, {
        value: utils.parseEther('0.1'),
      })

    questions = await askmi.questions(accounts[1].address)

    expect(questions[0].tips.toString()).eq('1')
  })

  it('updateTip() works for ERC20', async () => {
    await askmi.updateTip(functionsAddress, parseEth('0.1'), daiAddress)

    let tip = await askmi._tip()

    expect(tip[0]).eq(daiAddress)
    expect(tip[1].toString()).eq(parseEth('0.1'))
  })

  it('issueTip() works for ERC20', async () => {
    await askmi
      .connect(accounts[1])
      .issueTip(functionsAddress, accounts[1].address, 1)

    questions = await askmi.questions(accounts[1].address)

    expect(questions[1].tips.toString()).eq('1')
  })

  it('updateTiers() drops support for ETH', async () => {
    await askmi.updateTiers(functionsAddress, constants.AddressZero, [])

    let tiers = await askmi.getTiers(constants.AddressZero)
    expect(tiers.length).eq(0)

    supportedTokens = await askmi.supportedTokens()
    expect(supportedTokens[0]).eq(daiAddress)
    expect(supportedTokens.length).eq(1)
  })

  it('ask() fails because ETH is not supported', async () => {
    let qs = await askmi.questions(accounts[1].address)

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
          { value: utils.parseEther('0.01') }
        )
    ).to.be.rejected

    questions = await askmi.questions(accounts[1].address)

    expect(questions.length).eq(qs.length)
  })

  it('updateTiers() drops support for ERC20', async () => {
    await askmi.updateTiers(functionsAddress, daiAddress, [])

    let tiers = await askmi.getTiers(daiAddress)

    expect(tiers.length).eq(0)

    let supportedTokens = await askmi.supportedTokens()

    expect(supportedTokens.length).eq(0)
  })

  it('ask() fails because ERC20 is not supported', async () => {
    let qs = await askmi.questions(accounts[1].address)

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

    questions = await askmi.questions(accounts[1].address)

    expect(questions.length).eq(qs.length)
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
