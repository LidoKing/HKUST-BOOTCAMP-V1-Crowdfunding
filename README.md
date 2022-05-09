# Lidogogo

A crowdfunding platform with partial fund release feature to protect funders and integration of yield farming to fully utilize idle locked funds.

General flow:

1. Builders create project (funding)
2. Builders submit development plan (phase deadlines and fund allocation), phase 0 starts (voting)
3. Stake all funds for yield farming
4. Builders submit proposal to proceed to next phase (voting)
5. Builders claim funds for the phase, withdrawing corresponding amount funds from yield farm, and starts development
6. Funders can claim generated interest upon completion of whole project (last phase has passed)

## Phased Fund Release

The level of protection that funders have in current crowdfunding platforms remains low, leading to problems problems such as scam projects where builders just take all the money and do nothing, and delivery of products that fall short of expectations.

Lidogogo tackles this problem by integrating a phased fund release feature so that instead of a one-time release, fund pools are divided into portions and 'allocated' to the corresponding phase of development. Builders have to first submit proposal/plan for the phase they want to proceed to and only if the phase is passed (through voting) can the funds be released which then they can start development.

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
e.g. \_deadlines[20/5, 20/6, 10/7], block.timestamp = 8/5
Phase 0: 8/5-13/5; Phase 1: 13/5-20/5; Phase 2: 20/5-20/6; Phase 3: 20/6-10/7

### Proposal Submission

Actual development starts after phase 0 is passed and builders submit phase-specific proposal. For phases after phase 1, builders should also provide proofs of work of the previous phase in addition to just plannings for the proceeding phase. Actual details of proposal is handled at the front-end. Builders will submit proposals through `phaseProposal` function for phases after phase 0.

As proposal details are handled at the front-end, proposal function of the contract is basically initiation of new voting round and voting status is encapsulated in `Proposal` struct.

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
