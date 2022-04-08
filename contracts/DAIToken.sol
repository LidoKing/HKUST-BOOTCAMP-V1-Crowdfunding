pragma solidity >=0.8.4 <0.9.0;

interface IDAI {
    function allowance(address arg1, address arg2) public returns (uint256);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public returns (bool);
}
