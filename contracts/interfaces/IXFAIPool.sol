interface IXfaiPool {
    function getXfaiCore() external view returns (address);
    function poolToken() external view returns (address);
    function initialize(address _token, address _dexfaiDaoBridge) external;
    function getStates() external view returns (uint, uint, uint);
    function update(uint _balance, uint _r, uint _w) external;
    function mint(address _to, uint _amount) external;
    function burn(address _to, uint _amount) external;
    function linkedTransfer(address _token, address _to, uint256 _value) external;

    function totalSupply() external view returns (uint);
    function transfer(address _recipient, uint _amount) external returns (bool);
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint);
    function transferFrom(address _sender, address _recipient, uint _amount) external returns (bool);
    function approve(address _spender, uint _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);

    event Sync(uint _reserve, uint _w);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
    event Write(uint _r, uint _w, uint _blockTimestamp);
}
