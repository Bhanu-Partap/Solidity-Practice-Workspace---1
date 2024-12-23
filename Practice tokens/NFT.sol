// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract myNFT is ERC721URIStorage, Ownable{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    constructor()ERC721("FIRSTNFT", " FNT"){}

    function mintNFT(address recipient , string memory tokenURI) public onlyOwner returns(uint256){
        _tokenIds.increment();

        uint256 newItemId=_tokenIds.current();
        _mint(recipient , newItemId);    
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }


}

