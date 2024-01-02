// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol";

contract ERC1155MYTOKEN  is Ownable, ERC1155Supply {
        uint256 public maxSupply= 20;
         uint256 public PublicPrice= 1 wei;
     //mapping(uint256 => address) public _owners;
   uint public constant Token_Id=1;
      mapping(uint256 => uint256) public _totalSupply;

    constructor()
        ERC1155("https://gateway.pinata.cloud/ipfs/QmZ1cAGhixojEhamSgqbdPVexCvAL5TJF1iSpQAx9DtQR2/1.json")
    {
             _mint(msg.sender, Token_Id, 100, "");
          //   _totalSupply[Token_Id] = 100;
    }

    
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
      function uri(uint256 _id) public view virtual override returns (string memory) {
      require(exists(_id),"uri not exists token");
      return string(abi.encodePacked(super.uri(_id), Strings.toString(_id),".json"));
    }
     function ownerOf(uint256 _id, address owner)public  view  returns(bool){
         return balanceOf(owner, _id)!=0;
     }

        function mint(uint256 _id, uint256 _amount) public payable {
        require (msg.value>=PublicPrice*_amount,"not enough money");
         require(_totalSupply[_id]+ _amount <= maxSupply, "Exceeds maximum supply");
        _mint(msg.sender,_id, _amount, "");
         _totalSupply[_id] += _amount;

    }  
    function getcontractaddress() public returns(address){
      return address(this);
    }

 }