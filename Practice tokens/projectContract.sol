// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;


    Counters.Counter private _tokenIds;

    constructor() ERC721("Car Ethusiast", "NSX") {}
    string baseURI = "https://gateway.pinata.cloud/ipfs/QmZ1cAGhixojEhamSgqbdPVexCvAL5TJF1iSpQAx9DtQR2/";


    function mintNFT(address recipient) public onlyOwner 
    {

            uint newItemId = _tokenIds.current();
            _mint(recipient, newItemId);
            _setTokenURI(newItemId, string(abi.encodePacked(baseURI,Strings.toString(newItemId),".json")));
            _tokenIds.increment();
    }
  function getcontractaddress() public view returns(address){
      return address(this);
    }

    }