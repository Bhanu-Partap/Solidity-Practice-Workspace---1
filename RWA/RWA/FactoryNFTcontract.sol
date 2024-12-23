// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable@4.9.6/proxy/utils/Initializable.sol";
import "./Proxy/BeaconProxyNFTdynamic.sol";
import "./Vault.sol";

contract FactoryNFTcreator is Initializable {
    struct Project {
        address owner;
        address NFTAddress;
        string AssetName;
        string AssetSymbol;
        address projectToken;
        address projectVault;
    }

    struct SignatoryRole {
        address Signatory;
        address SignatoryOnchainId;
        string Role;
    }

    event createdProject(
        uint256 projectId,
        address projectOwner,
        address NFTAddress
    );

    uint256 public ProjectID;
    address public Admin;
    address public IdentityFactory;
    address beaconNftUpgradable;
    mapping(uint256 => Project) public Assets;
    mapping(address => uint256) collectionToProjectId;
    mapping(address => uint256[]) ownerToProjectId;

    modifier onlyAdmin() {
        require(msg.sender == Admin, "Caller must be admin");
        _;
    }

    function init(
        address admin,
        address _beaconNftUpgradable,
        address _identityFactory
    ) public initializer {
        Admin = admin;
        beaconNftUpgradable = _beaconNftUpgradable;
        IdentityFactory = _identityFactory;
    }

    function createProject(
        address _owner,
        string memory assetName,
        string memory assetSymbol,
        SignatoryRole[] memory team,
        uint256 _assetCount
    ) public onlyAdmin {
        ProjectID++;
        address projectToken = address(new GEMERC20(assetName, assetSymbol));

        address assetCollection = address(
            new nftCollectionBeacon(
                beaconNftUpgradable,
                assetName,
                assetSymbol,
                IdentityFactory,
                Admin,
                _owner,
                address(this)
            )
        );
        address projectVault = address(
            new Vault(projectToken, assetCollection, Admin)
        );

        collectionToProjectId[assetCollection] = ProjectID;
        ownerToProjectId[_owner].push(ProjectID);

        Assets[ProjectID].NFTAddress = assetCollection;
        Assets[ProjectID].owner = _owner;
        Assets[ProjectID].AssetName = assetName;
        Assets[ProjectID].AssetSymbol = assetSymbol;
        Assets[ProjectID].projectToken = projectToken;
        Assets[ProjectID].projectVault = projectVault;
        DynamicNFT(assetCollection).addAsset(_assetCount);

        for (uint256 i = 0; i < team.length; i++) {
            DynamicNFT(assetCollection).SetSignatory(
                team[i].Signatory,
                team[i].SignatoryOnchainId,
                team[i].Role
            );
        }

        DynamicNFT(assetCollection).SetSignatory(
            _owner,
            IDfactory(IdentityFactory).getidentity(_owner),
            "owner"
        );
        DynamicNFT(assetCollection).setVault(projectVault);
        GEMERC20(projectToken).setVault(projectVault);

        emit createdProject(ProjectID, _owner, assetCollection);
    }

    function ownerByProjectId(uint256 projectId) public view returns (address) {
        return Assets[projectId].owner;
    }

    function projectByOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        return ownerToProjectId[_owner];
    }

    function collectionFromProjectId(uint256 projectId)
        public
        view
        returns (address)
    {
        return Assets[projectId].NFTAddress;
    }
}
