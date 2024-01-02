 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Multitokens is ERC1155, Ownable, ERC1155Supply {
    constructor() ERC1155("https://gateway.pinata.cloud/ipfs/QmZ1cAGhixojEhamSgqbdPVexCvAL5TJF1iSpQAx9DtQR2/") {}

    uint256 public constant maxSupply = 50;
    bool public publicMintOpen = false;
    bool public allowListMintOpen = true;

    // mapping
    mapping(address => bool) allowList;

    function editMintState(bool _publicMintOpen, bool _allowListMintOpen)
        external
        onlyOwner
    {
        publicMintOpen = _publicMintOpen;
        allowListMintOpen = _allowListMintOpen;
    }

    function setAllowList(address[] calldata addresses) external onlyOwner{
        for(uint i = 0; i< addresses.length ; i++){
            allowList[addresses[i]] = true;
        }
    }

    function allowListMint(uint256 id, uint256 amount) public payable {
        require(allowListMintOpen, "Its Closed");
        require(allowList[msg.sender], "You are not listed in alowwedlist");
        require(msg.value == 20 wei * amount, "Not Enough money sent !");
        require(id < 2, "Sorry you are mintng wrong nft");
        require(totalSupply(id) + amount <= maxSupply, "Limiy exeeded");
        _mint(msg.sender, id, amount, " ");
    }

    function mint(uint256 id, uint256 amount) public payable {
        require(publicMintOpen, "Its closed");
        require(id < 2, "Sorry you are mintng wrong nft");
        require(msg.value == 40 wei * amount, "Enter right amount");
        require(totalSupply(id) + amount <= maxSupply, "Limiy exeeded");
        _mint(msg.sender, id, amount, " ");
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        // return string(abi.encodePacked(super.uri(id),Strings.toString(id));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
