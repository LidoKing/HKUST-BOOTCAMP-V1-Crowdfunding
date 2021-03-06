# Lidogogo

Lidogogo is a crowdfunding platform with partial fund release feature to protect funders and integration of yield farming to fully utilize idle locked funds.

General flow:

1. Builders create project (funding)
2. Builders submit development plan (phase deadlines and fund allocation), phase 0 starts (voting)
3. Stake all funds for yield farming (currently, at Aave)
4. Builders submit proposal to proceed to next phase (voting)
5. Builders claim funds for the phase, withdrawing corresponding amount funds from yield farm, and starts development
6. Step 4 and 5 repeats until project development is complete

Architecture diagram:

![Architecture Diagram](https://user-images.githubusercontent.com/55234791/167614814-06c4032a-ca46-495d-8110-3e65a97ef1e3.jpeg)

## Phased Fund Release

The level of protection that funders have in current crowdfunding platforms remains to be low, leading to problems problems such as scam projects where builders just take all the money and do nothing, and delivery of products that fall short of expectations.

Lidogogo tackles this problem by integrating a phased fund release feature so that instead of a one-time release, the fund pool is divided into portions and 'allocated' to the corresponding phase of development. Builders have to first submit proposal/plan for the phase they want to proceed to and only if the proposal is passed (through voting) can the funds be released which then they can start development.

### Development Initiation

After successful funding, builders will submit an overall plan for the development of the project and details including the number of phases to have, deadlines for different phases (compulsory), expected amount of funds allocated for corresponding phases (compulsory), and other additional information that builders would like to let funders know. The submission of proposal is done through the `initiateDevelopment` function and at the same time, phase 0 and the first round of voting starts.

```shell
function initiateDevelopment(
    uint256 _projectId,
    uint256[] calldata _deadlines,
    uint256[] calldata _fundAllocation
) external initiable(_projectId) {}
```

Deadlines and fund allocations are passed in the form of array where the same phase should have the same index in the arrays.
5 day voting period should be taken into account when deciding and submitting deadlines plan:

```shell
_deadlines[20/5, 20/6, 10/7], block.timestamp = 8/5
Phase 0: 8/5-13/5; Phase 1: 13/5-20/5; Phase 2: 20/5-20/6; Phase 3: 20/6-10/7
```

### Proposal Submission

Actual development starts after phase 0 is passed and builders submit phase-specific proposal. For phases after phase 1, builders should also provide proofs of work of the previous phase in addition to just plannings for the proceeding phase. As actual details of proposal is handled at the front-end, proposal function of the contract is basically initiation of new voting round where voting status is encapsulated in `Proposal` struct.. Builders will submit proposals through `phaseProposal` function for phases after phase 0.

```shell
struct Proposal {
    uint64 voteStart;
    uint64 voteEnd;
    // ID for next improvement proposal
    uint8 ipId;
    bool reworked;
    mapping(uint256 => Improvement) improvements;
    // Voting types: 0 - For, 1 - Against, 2 - Abstain, 3 - Delegated
    mapping(address => uint256) voteType;
    mapping(uint256 => uint256) typeTrack;
    mapping(address => address) delegated;
    mapping(address => uint256) power;
    mapping(address => bool) voted;
}
```

### Proposal Voting

Proposal voting is an essential process for them to participate in the development process and monitor the progress of the project. Voting power of funders is is the amount they funded for the project (e.g. funded $1000, voting power = 1000) and threshold of passing the proposal is 80% of total votes (total amount funded). Again, builders can only funds for the phase if proposal is passed.

#### Voting Types

- For (1) - Supports proposal
- Against (2) - Reject proposal, propose improvement
- Abstain (3) - No stance
- Delegate (4) - Transfer all voting power to delegatee

There is no 'default' vote type. Funders must call voting function to register for a type.

### Resolution Flow

For funders who reject a proposal, suggestions/improvements are expected to be provided so that builders can improve their proposal and submit a rework of it. Improvements are wrapped in `Proposal` struct and builders can obtain all improvements suggested through `getImprovements`.

```shell
uint8 ipId;
mapping(uint256 => Improvement) improvements;
```

There is only one chance for rework and it should be submitted within two days after the voting of initial proposal has ended. If no rework is submitted or the rework of proposal is rejected again, project development will be terminated and refunding phase will start.

### Refund

For simplicity, `mapping(address => uint256) fundedAmount` serves as a virtual refund token so that an individual token contract is not needed. Total number of tokens issued is tracked with `uint256 totalSupply`. Both are wrapped inside the `Project` struct.

#### Refund Amount Calculation

```shell
(fundedAmount / totalSupply) * remaining funds
```

This is identical to multiplying the remaining funds in fund pool by the percentage ownership of virtual refund token.

## Yield Farming

The implementation of phased fund release means that unreleased funds locked in the contract will just remain idle. Lidogogo unleashes the full potential of the funds by integrating DeFi to generate yield from these idle funds, providing an extra benefit for builders or funders. During project initiation, apart from State and Proposal initialization, all funds are deposited to Aave V3 for staking. This can be easily accomplished by connecting to the `supply` and `withdraw` functions from Aave V3 core contract.

### Accrued interest

Two scenarios triggering withdrawal of funds from aave back to crowdfunding contract:

- Builders claim funds to start development after successful proposal
- Rework of proposal is rejected and funders refund

First scenario:
Normally, builders will just get the amount of fund allocated for the corresponding phase. Thanks to the yield-farming mechanism, there will be interest accrued throughout project development. When the last phase of development is reached, builders can claim all remaining funds including all generated interest as a bonus.

Second scenario:
When a project ends up failing, in addition to the reduction of losses thanks to the phased fund release feature, the yield farming mechanism can compensate some of funders losses.

## Potential/Future Features

- Accept funding in the form of other cryptocurrencies (currently only stablecoin, DAI)
- Provide more options for yield farming, not just Aave
- Crosschain funding
- Development delays -> vote on whether accept delay or not, push deadlines
