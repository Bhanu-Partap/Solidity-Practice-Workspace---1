// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC-721.sol";
import "./ERC-1155.sol";
import "./ERC-20.sol";

contract NFTstaker
{
    ERC1155MYTOKEN token;
    ERC20Basic token_20;
    NFT nft;

    constructor(ERC1155MYTOKEN _addressERC1155,NFT  _addressERC721,ERC20Basic _addressERC20 ){
        token = _addressERC1155;
        nft = _addressERC721;
        token_20=_addressERC20;
    }
    uint itemId=1;
    struct SellingItem{
        uint tokenId;
        string TypeToken;
        uint amount;
        address owner;
        uint fixedPrice;
        }
    struct auction{
        uint tokenId;
        string TypeToken;
        uint amount;
        uint timestamp;
        address owner;
        uint previousBid;
        uint currentBid;
        address previousBidder;
        address CurrentBider;
        uint AuctionTime;
    }
    mapping(uint => bundle[]) public bundledata;
    struct bundle {
        uint256 id;
        address _address;
    }
    uint BundleId=1;
    mapping(uint => uint256) bundle_selling_price;
    mapping(uint => auction) bundle_auction_data;

    mapping(uint => SellingItem) public sell;
    mapping(uint => auction) public Auction;

    
    event bundleCreated(uint _BundleId,uint[],uint Price);
    event bundleOwnerChange(uint ,uint[],uint);

    function bundlelist(
        bool _sell,
        bool _auction,
        uint256[] calldata id_array,
        uint256 price
    ) public {
        require(_sell != _auction,"decide want to sell or auction");
        if (_sell) {
            for (uint256 i = 0; i < id_array.length; i++) {
                require(
                    nft.ownerOf(id_array[i]) == msg.sender,
                    "you are not owner"
                );
                bundledata[BundleId].push(
                    bundle(id_array[i], msg.sender)
                    
                );
                
            }
            bundle_selling_price[BundleId] = price;
            emit bundleCreated(BundleId,id_array,bundle_selling_price[BundleId]);
            BundleId++ ;
        } else if (_auction) {
            for (uint256 i = 0; i < id_array.length; i++) {
                require(
                    nft.ownerOf(id_array[i]) == msg.sender,
                    "you are not owner"
                );
                bundledata[BundleId].push(
                    bundle(id_array[i], msg.sender)
                );
            }
            bundle_auction_data[BundleId] = auction({
                tokenId : BundleId,
                TypeToken:"Erc721",
                amount : 1,
                timestamp : block.timestamp,
                owner : msg.sender,
                previousBid:0,
                currentBid : 0,
                previousBidder :address(0),
                CurrentBider : address(0),
                AuctionTime: block.timestamp + 3600
            });
            emit bundleCreated(BundleId,id_array,0);
            BundleId++;
        }
    }

    function buy_bundle(uint _BundleId) public payable {
        require(
            bundle_selling_price[_BundleId] == msg.value,
            "you are not paying enough ether"
        );
        for (uint256 i = 0; i < bundledata[_BundleId].length; i++) {
            nft.transferFrom(
                bundledata[_BundleId][i]._address,
                msg.sender,
                bundledata[_BundleId][i].id
            );
        }
        //emit  bundleOwnerChange(_BundleId,bundledata[_BundleId].bundle());
        delete bundledata[_BundleId];
    }

    function cancel_bundle(uint _BundleId) public {
        require(msg.sender == bundledata[_BundleId][0]._address,"you are not the owner to cancel");
        delete bundledata[_BundleId];
        delete bundle_selling_price[_BundleId];
        delete bundle_auction_data[_BundleId];
    }

    function bundle_bid(uint _BundleId,uint amount) public payable returns(string memory) {
        require(_BundleId != 0,"item is not registed for auction");
        require(block.timestamp <bundle_auction_data[_BundleId].AuctionTime,"auction time already ended so please cancel or end the auction");
        require(amount >bundle_auction_data[_BundleId].currentBid,"Bid is not higher than previous bid");
        if(bundle_auction_data[_BundleId].currentBid == 0){
            require(msg.sender != bundle_auction_data[_BundleId].owner," owner can't BID");
            bundle_auction_data[_BundleId].currentBid = amount;
            bundle_auction_data[_BundleId].CurrentBider = msg.sender;
            }
        else if(bundle_auction_data[_BundleId].currentBid !=0) {
            bundle_auction_data[_BundleId].previousBid = bundle_auction_data[_BundleId].currentBid ;
            bundle_auction_data[_BundleId].previousBidder =  bundle_auction_data[_BundleId].CurrentBider;
            bundle_auction_data[_BundleId].currentBid = amount;
            bundle_auction_data[_BundleId].CurrentBider = msg.sender;
            payable(bundle_auction_data[_BundleId].previousBidder).transfer(bundle_auction_data[_BundleId].previousBid);
            }
        return "bid successfully done";
        }
    

    function HighestBundleBid(uint _BundleId) public view returns(uint,address)
    {
        return (bundle_auction_data[_BundleId].currentBid, bundle_auction_data[_BundleId].CurrentBider);
    }  


    function BundleAuctionEnds(uint Id) public payable returns(string memory,address,uint)
    {
        require(bundle_auction_data[Id].currentBid!=0,"firstly place a bid");
        payable(bundle_auction_data[Id].owner).transfer(bundle_auction_data[Id].currentBid);
        bundle_auction_data[Id].owner = payable(bundle_auction_data[Id].CurrentBider);
        bundle_auction_data[Id].previousBid = bundle_auction_data[Id].currentBid ;
        bundle_auction_data[Id].previousBidder =  bundle_auction_data[Id].CurrentBider;
        bundle_auction_data[Id].currentBid = 0;
        bundle_auction_data[Id].CurrentBider = address(0);
        nft.transferFrom(msg.sender,bundle_auction_data[Id].owner,Id); 
        

        return ("Auction successfully given to highest bidder : highest bidder and amount is ",Auction[Id].owner,Auction[Id].previousBid) ;
    }


    function BundlecancelAuction(uint Id) public payable returns(string memory)
    {
        require(bundle_auction_data[Id].currentBid!=0,"firstly place a bid");
        payable(bundle_auction_data[Id].CurrentBider).transfer(bundle_auction_data[Id].currentBid);
        bundle_auction_data[Id].previousBid = 0 ;
        bundle_auction_data[Id].previousBidder =  address(0);
        bundle_auction_data[Id].currentBid = 0;
        bundle_auction_data[Id].CurrentBider = address(0);
        return ("Auction is been canceled");
    } 

    function registerSell(string memory want_to_sell_or_auction,uint _tokenId,uint _amount,string memory Type,uint Price)public returns(string memory)
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
    function bid(uint Id,uint amount)public payable returns(string memory)
    {
        require(itemId != 0,"item is not registed for auction");
        require(block.timestamp <Auction[Id].AuctionTime,"auction time already ended so please cancel or end the auction");

        require(amount > Auction[Id].currentBid,"Bid is not higher than previous bid");
        if(Auction[Id].currentBid == 0){
            require(msg.sender != Auction[Id].owner," owner can't BID");
            Auction[Id].currentBid = amount;
            Auction[Id].CurrentBider = msg.sender;
            }
        else if(Auction[Id].currentBid !=0) {
            Auction[Id].previousBid = Auction[Id].currentBid ;
            Auction[Id].previousBidder =  Auction[Id].CurrentBider;
            Auction[Id].currentBid = amount;
            Auction[Id].CurrentBider = msg.sender;
            payable(Auction[Id].previousBidder).transfer(Auction[Id].previousBid);
            }
        return "bid successfully done";
    
    }
    
    function Highest(uint Id) public view returns(uint,address)
    {
        return (Auction[Id].currentBid, Auction[Id].CurrentBider);
    }  


    function AuctionEnds(uint Id) public payable returns(string memory,address,uint)
    {
        require(Auction[Id].currentBid!=0,"firstly place a bid");
        payable(Auction[Id].owner).transfer(Auction[Id].currentBid);
        Auction[Id].owner = payable(Auction[Id].CurrentBider);
        Auction[Id].previousBid = Auction[Id].currentBid ;
        Auction[Id].previousBidder =  Auction[Id].CurrentBider;
        Auction[Id].currentBid = 0;
        Auction[Id].CurrentBider = address(0);
        if(keccak256(abi.encodePacked(Auction[Id].TypeToken)) == keccak256(abi.encodePacked("Erc721")) ){
           nft.transferFrom(msg.sender,Auction[Id].owner,Id); 
        }
        else{
           token.safeTransferFrom(msg.sender,Auction[Id].owner,Id,Auction[Id].amount,""); 
        }

        return ("Auction successfully given to highest bidder : highest bidder and amount is ",Auction[Id].owner,Auction[Id].previousBid) ;
    }


    function cancelAuction(uint Id) public payable returns(string memory)
    {
        require(Auction[Id].currentBid!=0,"firstly place a bid");
        payable(Auction[Id].CurrentBider).transfer(Auction[Id].currentBid);
        Auction[Id].previousBid = 0 ;
        Auction[Id].previousBidder =  address(0);
        Auction[Id].currentBid = 0;
        Auction[Id].CurrentBider = address(0);
        return ("Auction is been canceled");
    } 

    function LowerPrice(uint Id,uint Price)public returns(string memory){
        sell[Id].fixedPrice=Price;
        return ("discounted the token");   
    }

    function BuyNft(uint Id)public payable returns(string memory){
        require(sell[Id].tokenId != 0 , "no item to sell");
        payable(sell[Id].owner).transfer(sell[Id].fixedPrice);
        if(keccak256(abi.encodePacked(Auction[Id].TypeToken)) == keccak256(abi.encodePacked("Erc721")) ){
           nft.transferFrom(msg.sender,Auction[Id].owner,Id); 
        }
        else{
           token.safeTransferFrom(msg.sender,Auction[Id].owner,Id,Auction[Id].amount,""); 
        }
        delete(sell[Id]);
        return ("token is sold at the desired price");
        }
        function getcontractaddress() public returns(address){
         return address(this);
      }
} 
