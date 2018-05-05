const Promise = require('bluebird');
const Splitter = artifacts.require("./Splitter.sol")

Promise.promisifyAll(web3.eth, { suffix: "Promise" })

contract('Splitter', async accounts => {

    const sender = accounts[0]
    const recipient1 = accounts[1]
    const recipient2 = accounts[2]

    let splitterInstance

    beforeEach("Initialise splitter contract instance", async () => {
        splitterInstance = await Splitter.deployed()
    })

    describe("Contract creation and initialise test cases ", async () => {

        it("Should set the correct owner", async () => {
            const contractOwner = await splitterInstance.owner()
            assert.strictEqual(sender, contractOwner, 'accounts[0] is not the owner')
        })

        it('Should revert for creation with value', async () => {
            try {
                const ValueInstance = await Splitter.new({ value: 10 });
                assert.isUndefined(ValueInstance, 'Instance should be undefined. Should throw error');
            } catch (err) {
                assert.include(err.message, 'revert', 'Contract created with value');
            }
        })

    })


    describe("Split functionality test cases ", async () => {

        describe("Success test cases", async () => {

            it("Should split value equally", async () => {
                const value = await web3.toWei(10, "ether");
                const recipient1InitialValue = await web3.fromWei(web3.eth.getBalance(recipient1), "ether").toNumber()
                const recipient2InitialValue = await web3.fromWei(web3.eth.getBalance(recipient2), "ether").toNumber()

                const instance = await splitterInstance.splitFunds(recipient1, recipient2, { from: sender, value: value })
                assert.strictEqual(await web3.fromWei(web3.eth.getBalance(recipient1), "ether").toNumber(), recipient1InitialValue + 10 / 2)
                assert.strictEqual(await web3.fromWei(web3.eth.getBalance(recipient2), "ether").toNumber(), recipient2InitialValue + 10 / 2)
            })


            it('Should event LogSplitFunds generated correctly ', async () => {
                const value = await web3.toWei(10, "ether")
                const txObject = await splitterInstance.splitFunds(recipient1, recipient2, { value, from: sender })
                const logs = txObject.logs
                const firstLogArgs = logs[0].args
                const amountPerSingleUser = web3.toBigNumber(firstLogArgs.amount).toString(10)
                assert.strictEqual(logs.length, 1, 'incorrect number of logs')
                assert.strictEqual(firstLogArgs.sender, sender, 'sender is not correct in log')
                assert.strictEqual(firstLogArgs.recipient1, recipient1, 'recipient1 is not correct in log')
                assert.strictEqual(firstLogArgs.recipient2, recipient2, 'recipient2 is not correct in log')
                assert.equal(amountPerSingleUser, value, 'splitted amount is incorrect')
            });

        })

        describe('Failue test cases', async () => {

            it("Should fail with 0 value", async () => {
                try {
                    const instance = await splitterInstance.splitFunds(recipient1, recipient2, { from: sender })
                    assert.isUndefined(instance, 'With 0 value split return something')
                } catch (err) {
                    assert.include(err.message, 'revert', 'no revert with 0 value');
                }
            })

            it('Should fail if sender is first recipient', async () => {
                try {
                    const instance = await splitterInstance.splitFunds(recipient1, recipient2, { from: recipient1, value: 10 })
                    assert.isUndefined(instance, 'if sender is the first beneficiary split return something');
                } catch (err) {
                    assert.include(err.message, 'revert', 'no revert if sender is the first recipient');
                }
            })

            it('Should fail if sender is second recipient', async () => {
                try {
                    const instance = await splitterInstance.splitFunds(recipient1, recipient2, { from: recipient2, value: 10 })
                    assert.isUndefined(instance, 'if sender is the first beneficiary split return something');
                } catch (err) {
                    assert.include(err.message, 'revert', 'no revert if sender is the first recipient');
                }
            })

            it('Should fail if recipient1 is recipient2', async () => {
                try {
                    const instance = await splitterInstance.splitFunds(recipient1, recipient1, { from: sender, value: 10 })
                    assert.isUndefined(instance, 'if recipient1 is secondBeneficiary split return something')
                } catch (err) {
                    assert.include(err.message, 'revert', 'no revert if firstBeneficiary is secondBeneficiary')
                }
            })

            it('Should fail if recipient1 is not present', async () => {
                try {
                    const instance = await splitterInstance.splitFunds(0x00, recipient2, { from: sender, value: 10 })
                    assert.isUndefined(instance, 'if recipient1 is 0x00 split return something')
                } catch (err) {
                    assert.include(err.message, 'revert', 'no revert if firstBeneficiary is secondBeneficiary')
                }
            })

            it('Should fail if recipient2 is not present', async () => {
                try {
                    const instance = await splitterInstance.splitFunds(recipient1, 0x00, { from: sender, value: 10 })
                    assert.isUndefined(instance, 'if recipient1 is 0x00 split return something')
                } catch (err) {
                    assert.include(err.message, 'revert', 'no revert if firstBeneficiary is secondBeneficiary')
                }
            })

        });


    })



})

