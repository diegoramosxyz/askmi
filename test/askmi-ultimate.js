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

  before(async () => {
    accounts = await getSigners()

    // Deploy ERC20
    daiFactory = await getContractFactory('contracts/ERC20.sol:MyToken')
    dai = await daiFactory.deploy('DAI', 'DAI')
    daiAddress = (await dai).address

    // Transfer DAI to second account
    await dai.transfer(accounts[1].address, parseDai('1000.0'))

    // Deploy askmi
    askmiFactory = await getContractFactory(
      'contracts/askmi-ultimate.sol:AskMiUltimate'
    )
    // Test deploying the contract with support for neither
    // ETH not ERC20.
    // This effectively closes the contract for no further
    // interactions
    askmi = await askmiFactory.deploy(
      accounts[0].address,
      accounts[0].address,
      []
      // [parseEth('1.0')]
    )

    // Approve ERC20 spending
    await dai
      .connect(accounts[1])
      .approve((await askmi).address, parseDai('1000.0'))
  })

  it('has all correct initial values', async () => {
    let fee = await askmi.fee()
    let questioners = await askmi.getQuestioners()
    let tipAndTiers = await askmi.getTipAndTiers(constants.AddressZero)
    let owner = await askmi.owner()

    expect(fee).eq('200')
    expect(tipAndTiers.length).eq(0)
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

  it('updateTipAndTiers() adds support for ETH', async () => {
    let tx = await askmi.updateTipAndTiers(constants.AddressZero, [
      parseEth('0.01'),
      parseEth('1.0'),
    ])

    await tx.wait()

    let tipAndTiers = await askmi.getTipAndTiers(constants.AddressZero)

    expect(tipAndTiers.length).eq(2)
  })

  it('updateTipAndTiers() adds support for ERC20', async () => {
    let tx = await askmi.updateTipAndTiers(daiAddress, [
      parseDai('1.0'),
      parseDai('10.0'),
      parseDai('25.0'),
    ])

    await tx.wait()

    tipAndTiers = await askmi.getTipAndTiers(daiAddress)

    expect(tipAndTiers.length).eq(3)
  })

  it('supportedTokens() returns tokens', async () => {
    let supportedTokens = await askmi.getSupportedTokens()

    expect(supportedTokens[0]).eq(constants.AddressZero)
    expect(supportedTokens[1]).eq(daiAddress)
    expect(supportedTokens.length).eq(2)
  })

  it('ask() works for ETH', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .ask(
        constants.AddressZero,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1,
        { value: utils.parseEther('1.0') }
      )

    await tx.wait()

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('ask() works for ERC20', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .ask(
        daiAddress,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1
      )
    await tx.wait()

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(2)
  })

  it('removeQuestion() works with ETH', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .removeQuestion(accounts[1].address, 0)

    await tx.wait()

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('removeQuestion() works with ERC20', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .removeQuestion(accounts[1].address, 0)

    await tx.wait()

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(0)
  })

  it('respond() works with ETH', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .ask(
        constants.AddressZero,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1,
        { value: utils.parseEther('1.0') }
      )

    await tx.wait()

    await askmi
      .connect(accounts[0])
      .respond(
        accounts[1].address,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        0
      )

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('respond() works with ERC20', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .ask(
        daiAddress,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1
      )

    await tx.wait()

    await askmi
      .connect(accounts[0])
      .respond(
        accounts[1].address,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        1
      )

    let questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(2)
  })

  it('issueTip() works for ETH', async () => {
    let tx = await askmi
      .connect(accounts[1])
      .issueTip(accounts[1].address, 0, { value: utils.parseEther('0.01') })

    await tx.wait()

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions[0].tips.toString()).eq('1')
  })

  it('issueTip() works for ERC20', async () => {
    let tx = await askmi.connect(accounts[1]).issueTip(accounts[1].address, 1)

    await tx.wait()

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions[1].tips.toString()).eq('1')
  })

  it('updateTipAndTiers() drops support for ETH', async () => {
    let tx = await askmi.updateTipAndTiers(constants.AddressZero, [])

    await tx.wait()

    let tipAndTiers = await askmi.getTipAndTiers(constants.AddressZero)
    expect(tipAndTiers.length).eq(0)

    supportedTokens = await askmi.getSupportedTokens()
    expect(supportedTokens[0]).eq(daiAddress)
    expect(supportedTokens.length).eq(1)
  })

  it('updateTipAndTiers() drops support for ERC20', async () => {
    let tx = await askmi.updateTipAndTiers(daiAddress, [])

    await tx.wait()

    let tipAndTiers = await askmi.getTipAndTiers(daiAddress)

    expect(tipAndTiers.length).eq(0)

    let supportedTokens = await askmi.getSupportedTokens()

    expect(supportedTokens.length).eq(0)
  })
})
