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

# Development Initiation

After successful funding, builders will submit an overall plan for the development of the project and details including the number of phases to have, deadlines for different phases (compulsory), expected amount of funds allocated for corresponding phases (compulsory), and other additional information that builders would like to let funders know. The submission of proposal is done through the `initiateDevelopment()` function and at the same time, phase 0 and the first round of voting starts.

```shell
function initiateDevelopment(
    uint256 _projectId,
    uint256[] calldata _deadlines,
    uint256[] calldata _fundAllocation
) external initiable(_projectId) {}
```
