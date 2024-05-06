const { assert } = require("chai");
const { expectRevert, time } = require("@openzeppelin/test-helpers");

const DAOToken = artifacts.require("DAOToken");
const DAOContract = artifacts.require("DAOContract");

contract("captchaDAO", ([deployer, user1, user2, user3, recipient]) => {
  beforeEach(async () => {
    this.daoToken = await DAOToken.new("captchaDAO Token", "CAPT", "1000000" + "0".repeat(18), { from: deployer });
    this.dao = await DAOContract.new("captchaDAO Token", "CAPT", "1000000" + "0".repeat(18), { from: deployer });

    // Distribute some tokens for testing
    await this.daoToken.transfer(user1, "5000" + "0".repeat(18), { from: deployer });
    await this.daoToken.transfer(user2, "3000" + "0".repeat(18), { from: deployer });
    await this.daoToken.transfer(user3, "2000" + "0".repeat(18), { from: deployer });
  });

  it("should create a proposal and vote on it", async () => {
    // User1 creates a proposal
    await this.dao.createProposal("Fund project X", "100" + "0".repeat(18), recipient, {
      from: user1,
    });

    // Check the proposal details
    const proposal = await this.dao.proposals(0);
    assert.equal(proposal.id.toString(), "0");
    assert.equal(proposal.proposer, user1);
    assert.equal(proposal.description, "Fund project X");
    assert.equal(proposal.amount.toString(), "100" + "0".repeat(18));
    assert.equal(proposal.recipient, recipient);

    // User1 votes on the proposal
    await this.dao.vote(0, true, { from: user1 });

    // Fast-forward time to after the voting period
    await time.increase(time.duration.days(8));
    
    // Execute the proposal
    await this.dao.executeProposal(0, { from: user1 });
    
    // Check that the proposal has been executed
    assert.equal((await this.dao.proposals(0)).executed, true);
  });

  it("should not allow a user with insufficient tokens to create a proposal", async () => {
    // Try to create a proposal with insufficient tokens
    await expectRevert(
      this.dao.createProposal("Fund project X", "100" + "0".repeat(18), recipient, { from: user3 }),
      "Insufficient tokens to create proposal"
    );
  });

  it("should allow delegation and voting through a delegate", async () => {
    // User2 delegates their voting power to User1
    await this.dao.delegate(user1, { from: user2 });

    // User1 votes on behalf of User2
    await this.dao.vote(0, true, { from: user1 });

    // Ensure the vote counted correctly
    const proposal = await this.dao.proposals(0);
    assert.equal(proposal.yesVotes.toString(), "8000" + "0".repeat(18)); // User1's and User2's votes combined
  });

  it("should enforce timelocks on proposal execution", async () => {
    // User1 creates a proposal with a timelock
    const proposalId = (await this.dao.createProposal("Buy new hardware", "50" + "0".repeat(18), 
    recipient, { from: user1 })).logs[0].args.proposalId;

    // Set a timelock for 7 days
    await this.dao.setTimelock(proposalId, time.duration.days(7), { from: deployer });

    // Attempt to execute the proposal before the timelock expires
    await expectRevert(
      this.dao.executeProposal(proposalId, { from: user1 }),
      "Proposal is still under timelock"
    );
  });

  it("should handle proposal challenges and dispute resolutions", async () => {
    // User1 creates a proposal
    const proposalId = (await this.dao.createProposal("Update software licenses", "200" + "0".repeat(18), 
    recipient, { from: user1 })).logs[0].args.proposalId;

    // User2 challenges the proposal
    await this.dao.createChallenge(proposalId, "Challenge description", { from: user2 });

    // Resolve the challenge as valid
    await this.dao.resolveChallenge(proposalId, true, { from: deployer });

    // Check if the challenge has been marked as resolved
    const challenge = await this.dao.challenges(proposalId);
    assert.equal(challenge.resolved, true);
  });

  it("should fail to vote if the voting period is over", async () => {
        // User1 creates a proposal
        await this.dao.createProposal("New investment", "100" + "0".repeat(18), recipient, { from: user1 });

        // Fast-forward time beyond the voting period
        await time.increase(time.duration.days(8));

        // User2 tries to vote after the period has expired
        await expectRevert(
            this.dao.vote(0, true, { from: user2 }),
            "Voting period has expired"
        );
    });

    it("should prevent double voting by the same user", async () => {
        // User1 creates a proposal
        await this.dao.createProposal("New initiative", "100" + "0".repeat(18), recipient, { from: user1 });
        
        // User1 votes on the proposal
        await this.dao.vote(0, true, { from: user1 });

        // User1 tries to vote again
        await expectRevert(
            this.dao.vote(0, true, { from: user1 }),
            "Already voted"
        );
    });

    it("should allow the owner to withdraw funds", async () => {
        // Simulate receiving some funds (e.g., through a donation or fee)
        const initialBalance = web3.utils.toWei("10", "ether");
        await web3.eth.sendTransaction({ from: deployer, to: this.dao.address, value: initialBalance });

        // Withdraw funds
        const initialOwnerBalance = BigInt(await web3.eth.getBalance(deployer));
        await this.dao.withdraw(initialBalance, { from: deployer });
        const finalOwnerBalance = BigInt(await web3.eth.getBalance(deployer));

        // Check the owner's balance has increased appropriately
        assert(finalOwnerBalance > initialOwnerBalance, "Owner should have more ether after withdrawal");
    });

    it("should reject execution of proposals by non-participants", async () => {
        // User1 creates a proposal
        await this.dao.createProposal("Expand operations", "100" + "0".repeat(18), recipient, { from: user1 });

        // Fast-forward time to after the voting period
        await time.increase(time.duration.days(8));
        
        // Non-participant tries to execute the proposal
        await expectRevert(
            this.dao.executeProposal(0, { from: nonParticipant }),
            "Proposal already executed or not passed"
        );
    });

    it("should automatically reject proposals with insufficient votes", async () => {
        // User1 creates a proposal
        await this.dao.createProposal("Upgrade facilities", "100" + "0".repeat(18), recipient, { from: user1 });

        // User3 votes against the proposal
        await this.dao.vote(0, false, { from: user3 });

        // Fast-forward time to after the voting period
        await time.increase(time.duration.days(8));

        // User1 tries to execute the proposal
        await expectRevert(
            this.dao.executeProposal(0, { from: user1 }),
            "The proposal did not pass"
        );
    });
});
