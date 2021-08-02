const { expect } = require('chai')
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
    askmi = await askmiFactory.deploy(
      accounts[0].address,
      accounts[0].address,
      [parseEth('1.0')]
    )

    // Approve ERC20 spending
    await dai
      .connect(accounts[1])
      .approve((await askmi).address, parseDai('1000.0'))
  })

  it('has all correct initial values', async () => {
    let fee = await askmi.fee()
    let questioners = await askmi.getQuestioners()
    // let tiers = await askmi.tiers(daiAddress)
    let owner = await askmi.owner()

    expect(fee).eq('200')
    // expect(tiers[0]).eq('1000000000000000000')
    expect(questioners[0]).eq(constants.AddressZero)
    expect(owner).eq(accounts[0].address)
  })

  it('addERC20() works', async () => {
    // Support is disabled by default
    let tiers = await askmi.getTiers(daiAddress)
    expect(tiers.length).eq(0)

    let tx = await askmi.addERC20(daiAddress, [parseDai('1.0')])

    await tx.wait()

    tiers = await askmi.getTiers(daiAddress)

    expect(tiers[0].toString()).eq(parseDai('1.0'))
  })

  it('ask() works with ETH', async () => {
    let questions = await askmi.getQuestions(accounts[1].address)
    expect(questions.length).eq(0)

    let tx = await askmi
      .connect(accounts[1])
      .ask(
        constants.AddressZero,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        0,
        { value: utils.parseEther('1.0') }
      )
    await tx.wait()

    questions = await askmi.getQuestions(accounts[1].address)

    expect(questions.length).eq(1)
  })

  it('ask() works with ERC20', async () => {
    let questions = await askmi.getQuestions(accounts[1].address)
    expect(questions.length).eq(1)

    let tx = await askmi
      .connect(accounts[1])
      .ask(
        daiAddress,
        '0x744d7ad0f5893404994e4bfc6af6fb365439d15d7338b7f8ff1b39c5f3593fad',
        '0x12',
        '0x20',
        0
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
        0,
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
        0
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

  it('updateTiers() work for ETH', async () => {
    // Support is disabled by default
    let tiers = await askmi.getTiers(constants.AddressZero)
    expect(tiers.length).eq(1)
    expect(tiers[0].toString()).eq(parseEth('1.0'))

    let tx = await askmi.updateTiers(constants.AddressZero, [
      parseEth('1.0'),
      parseEth('10.0'),
    ])

    await tx.wait()

    tiers = await askmi.getTiers(constants.AddressZero)

    expect(tiers.length).eq(2)
    expect(tiers[0].toString()).eq(parseEth('1.0'))
    expect(tiers[1].toString()).eq(parseEth('10.0'))
  })

  it('updateTiers() work for ERC20', async () => {
    // Support is disabled by default
    let tiers = await askmi.getTiers(daiAddress)
    expect(tiers.length).eq(1)
    expect(tiers[0].toString()).eq(parseDai('1.0'))

    let tx = await askmi.updateTiers(daiAddress, [
      parseDai('1.0'),
      parseDai('10.0'),
    ])

    await tx.wait()

    tiers = await askmi.getTiers(daiAddress)

    expect(tiers.length).eq(2)
    expect(tiers[0].toString()).eq(parseDai('1.0'))
    expect(tiers[1].toString()).eq(parseDai('10.0'))
  })
})
