const { expect } = require('chai')
const {
  ethers: { utils, getSigners, getContractFactory },
} = require('hardhat')

describe('AskMi', () => {
  let oneEth = utils.parseEther('1.0')
  let accounts
  before(async () => {
    accounts = await getSigners()
    Factory = await getContractFactory('AskMi')
    contract = await Factory.deploy([oneEth])
  })

  it('asks a question', async () => {
    let tx = await contract
      .connect(accounts[1])
      .ask('question 1', 1, 2, 0, { value: oneEth })

    let { events } = await tx.wait()
    let questioner = events[0].args['_questioner']
    let qIndex = events[0].args['_qIndex']

    console.log({ questioner })
    console.log('qIndex: ', qIndex.toNumber())

    expect(qIndex.toNumber()).equals(0)
  })
})
