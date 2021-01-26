// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "./MerkleProof.sol";
import "./IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor {
    bytes32 public merkleRoot;
    address public owner;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) internal claimedBitMap;

    constructor(bytes32 _merkleRoot) public {
        merkleRoot = _merkleRoot;
        owner = msg.sender;
    }

    function isClaimed(uint256 index) public override view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) internal {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(
        uint256 index,
        address payable account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external virtual override {
        require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "MerkleDistributor: Invalid proof.");

        // Mark as claimed and send the BNB.
        _setClaimed(index);
        (bool success, bytes memory data) = account.call{value:amount}("ditto.money");
        require(success, 'DittoClaimDistributor: Transfer failed');

        emit Claimed(index, account, amount);
    }

    function withdrawAll(address payable to) external {
        require(msg.sender == owner);

        (bool success, bytes memory data) = to.call{value:address(this).balance}("ditto.money");
        require(success, 'DittoClaimDistributor: WithdrawAll failed');
    }
    
    receive() external payable {
    }
}
