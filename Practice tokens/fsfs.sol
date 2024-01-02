function registerSell(string memory want_to_sell_or_auction,uint tokenId,uint amount,string memory Type,uint Price)public returns(string memory)
    {
        if(keccak256(abi.encodePacked(want_to_sell_or_auction)) ==keccak256(abi.encodePacked( "sell")))
        {
            require(nft.ownerOf(_tokenId)==msg.sender||token.balanceOf(msg.sender,_tokenId)>0,"not authorised to stake");
            if (keccak256(abi.encodePacked(Type)) ==keccak256(abi.encodePacked( "Erc721")))
            {
            sell[itemId] = SellingItem(_tokenId,Type,1,msg.sender,Price);
            //get approval from ERC721 to transfer NFT in contract
            itemId++;
            return ("erc721 nft is been posted to selling");
            }
            else if(keccak256(abi.encodePacked(Type)) ==keccak256(abi.encodePacked( "Erc1155")))
            {
            sell[itemId] = SellingItem(_tokenId,Type,_amount,msg.sender,Price);
            //get approval from ERC721 to transfer NFT in contract
            
            itemId++;
            return("erc1155 token is been listed for selling ");      
            }
            else
            {
            return("enter valid token type whether Erc721 or Erc1155");
            }
        
        }
        
        else if(keccak256(abi.encodePacked(want_to_sell_or_auction)) ==keccak256(abi.encodePacked( "auction")))
        {
            require(nft.ownerOf(_tokenId)==msg.sender||token.balanceOf(msg.sender,_tokenId)>0,"not authorised to stake");
            if (keccak256(abi.encodePacked(Type)) ==keccak256(abi.encodePacked( "Erc721")))
            {
            uint _auction_time = block.timestamp + 1000;
            Auction[itemId] = auction(_tokenId,Type,1,block.timestamp,msg.sender,0,0,address(0),address(0),_auction_time);
            //get approval from ERC721 to transfer NFT in contract
            itemId++;
            return ("erc721 nft is been posted to selling");
            }
            else if(keccak256(abi.encodePacked(Type)) ==keccak256(abi.encodePacked( "Erc1155")))
            {
            uint _auction_time = block.timestamp + 1000;
            Auction[itemId] = auction(_tokenId,Type,_amount,block.timestamp,msg.sender,0,0,address(0),address(0),_auction_time);
            //get approval from ERC721 to transfer NFT in contract
            itemId++;
            return("erc1155 token is been listed for selling ");      
            }
            else
            {
            return("enter valid token type whether Erc721 or Erc1155");
            }
        }
    return ("enter valid type of selling option");
    }