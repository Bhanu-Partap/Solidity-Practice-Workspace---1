// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract DynamicNFT is ERC721, ERC721URIStorage, Ownable {
    
//     string[] IpfsUri = [
//         "https://gateway.ipfs.io/ipfs/bafybeihazdlyqco2a6jc4ptc4shl4gsybsvm2y3j3npvgyewgwc43f4tcu/yannis-zaugg-YKVIswI0iS8-unsplash.jpg",
//         "https://gateway.ipfs.io/ipfs/bafybeia5asmaaqfp7vbmuqppollg2nd5xu4gpvrnfkuf5zxslute3oep3q/wes-tindel-jpIrQ1Qm3gg-unsplash.jpg",
//         "https://gateway.ipfs.io/ipfs/bafybeiassvkzusygpyifpp23yxkpag4ia3thlxl4inijjwhwwobtkqi7xa/flavien-ESXhISyyHho-unsplash.jpg"
//     ];

//     uint interval;
//     uint lastTimeStamp;


//     constructor(uint _interval) ERC721("DynamicNFT", "DNFT"){
//         interval = _interval ;
//         lastTimeStamp = block.timestamp;
//     }

//     function safeMint(address to, uint256 tokenId, string memory uri)
//         public
//         onlyOwner
//     {
//         _safeMint(to, tokenId);
//         _setTokenURI(tokenId, uri);
//     }

//     // The following functions are overrides required by Solidity.

//     function tokenURI(uint256 tokenId)
//         public
//         view
//         override(ERC721, ERC721URIStorage)
//         returns (string memory)
//     {
//         return super.tokenURI(tokenId);
//     }

//     function supportsInterface(bytes4 interfaceId)
//         public
//         view
//         override(ERC721, ERC721URIStorage)
//         returns (bool)
//     {
//         return super.supportsInterface(interfaceId);
//     }

//     function checkUpkeep(bytes calldata ) external view returns(bool upkeepNeeded, bytes memory){
//         upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
//     }

//     function performUpkeep(bytes calldata ) external{
//             if((block.timestamp - lastTimeStamp)> interval){
//                 lastTimeStamp = block.timestamp;
//                 changeCar(0);
//             }
//     }
     
//     // function changeCar(uint256 _tokenId) public {
//     //     if(carstage(_tokenId) >=2 ){return; }
//     //     uint256 newVal= carstage(_tokenId)+1;
//     //     string memory newUri = IpfsUri[newVal];
//     //     _setTokenURI(tokenId, newUri);
//     // }

    


// }


// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract DynamicNFT is ERC721URIStorage {

    uint interval;
    uint lastTimeStamp;

     string[] IpfsUri = [
        "https://api.npoint.io/2367a54a38c79bbe9a95",
        "https://api.npoint.io/6bdca0b1ab9c55094110"
    ];

    constructor(uint256 _interval) ERC721("DynamicNFT", "DNFTs") {
        interval = _interval ;
        lastTimeStamp = block.timestamp;
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        // lastTimeStamp = block.timestamp;
        // if(lastTimeStamp + interval < block.timestamp){
        //     _setTokenURI(tokenId, IpfsUri[1]);
        // }
    }

    function checkUpkeep(bytes calldata ) external view returns(bool upkeepNeeded, bytes memory){
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata ) external{
            if((block.timestamp - lastTimeStamp) > interval){
                lastTimeStamp = block.timestamp;
            }
    }

    function changeUri(uint id,uint i) public {
        _setTokenURI(id, IpfsUri[i]);
    }

}