// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// Base contracts
import "./Common/IBEP20.sol";
import "./Common/BEP20.sol";
// OpenZeppelin libs
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// UniSwap libs
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// Dividends
import "./DividendTracker/AbstractDividends.sol";

contract CATSMAMA is BEP20, AbstractDividends {
    using SafeMath for uint256;
    // contract version
    string constant version = 'v1.0.0';
    uint256 constant initialSupply = 1_000_000_000_000_000 * 10 ** 18;
    IERC20 public catsToken;
    uint256 public maxWalletSize;

    // Keeps track of vests
    mapping(address => VestInfo) private _vests;

    // Keeps track of balances for address.
    mapping(address => uint256) private _balances;

    // Keeps track of which address are excluded from fee.
    mapping(address => bool) private _isExcludedFromFee;

    // Keeps track of which address are excluded from wallet size cap.
    mapping(address => bool) private _isExcludedFromWalletCap;

    // addresses that can make transfers before presale is over
    mapping(address => bool) public canTradeInPresale;

    // store addresses that a automatic market maker pairs
    mapping(address => bool) public automatedMarketMakerPairs;

    // Liquidity pool provider router
    IUniswapV2Router02 public uniswapV2Router;

    // This Token and WETH pair contract address.
    address internal _uniswapV2Pair;

    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;

    // Where marketing fee tokens are sent to.
    address public marketingWallet;

    // Where donation fee tokens are sent to.
    address public donationWallet;

    // Where development fee tokens are sent to.
    address public developmentWallet;

    // This percent of a transaction will be burnt.
    uint16 private _taxBurn;

    // This percent of a transaction sent to marketing.
    uint16 private _taxMarketing;

    // This percent of a transaction sent to donation.
    uint16 private _taxDonation;

    // This percent of a transaction sent to development.
    uint16 private _taxDevelopment;

    // This percent of a transaction will be dividend.
    uint16 private _taxDividend;

    // This percent of a transaction will be added to the liquidity pool. More details at https://github.com/Sheldenshi/ERC20Deflationary.
    uint16 private _taxLiquidity;

    // ERC20 Token Standard
    uint256 private _totalSupply;

    // A threshold for swap and liquify.
    uint256 private _minTokensBeforeSwap;

    // Whether a previous call of SwapAndLiquify process is still in process.
    bool private _inSwapAndLiquify;

    // whether the presale is over
    uint256 public presaleCompletedTimestamp;
    bool public isPresaleComplete;
    address[] public privateSaleWallets;
    bool  public vestingPerformed;

    bool private _autoSwapAndLiquifyEnabled;
    bool private _autoBurnEnabled;
    bool private _halfTaxEnabled = false;

    bool public _autoDividendProcessingEnabled = true;
    // processing auto-claiming dividends
    uint256 public transfersPerBatch = 6;

    // Return values of _getValues function.
    struct TokenFeeValues {
        // Amount of tokens for to transfer.
        uint256 amount;
        // Amount tokens charged for burning.
        uint256 burnFee;
        // Amount tokens charged for marketing.
        uint256 marketingFee;
        // Amount tokens charged for donation.
        uint256 donationFee;
        // Amount tokens charged for development.
        uint256 developmentFee;
        // Amount tokens charged for dividends.
        uint256 dividendFee;
        // Amount tokens charged to add to liquidity.
        uint256 liquifyFee;
        // Amount of total fee
        uint256 totalFee;
        // Amount tokens after fees.
        uint256 transferAmount;
    }

    // Return ETH values of _getSwapValues function.
    struct SwapingETHValues {
        // Amount ETH used for liquidity.
        uint256 liquidityETHAmount;
        // Amount ETH used for marketing.
        uint256 marketingETHAmount;
        // Amount ETH used for donation.
        uint256 donationETHAmount;
        // Amount ETH used for development.
        uint256 developmentETHAmount;
        // Amount ETH used for burn.
        uint256 burnETHAmount;
        // Amount ETH used for dividend.
        uint256 dividendETHAmount;
    }

    struct VestInfo {
        uint256 vestAmount;
        bool enabled;
    }

    /*
        Events
    */
    event Burn(address from, uint256 amount);
    event TaxBurnUpdate(uint16 previousTax, uint16 currentTax);
    event TaxDividendUpdate(uint16 previousTax, uint16 currentTax);
    event TaxMarketingUpdate(uint16 previousTax, uint16 currentTax);
    event TaxDonationUpdate(uint16 previousTax, uint16 currentTax);
    event TaxDevelopmentUpdate(uint16 previousTax, uint16 currentTax);
    event TaxLiquifyUpdate(uint16 previousTax, uint16 currentTax);
    event MinTokensBeforeSwapUpdated(uint256 previous, uint256 current);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensAddedToLiquidity
    );
    event ExcludeAccountFromFees(address account);
    event ExcludeAccountFromWalletCap(address account);
    event IncludeAccountInFee(address account);
    event EnabledAutoBurn();
    event EnabledAutoSwapAndLiquify();
    event DisabledAutoBurn();
    event DisabledAutoSwapAndLiquify();
    event Airdrop(uint256 amount);
    event ExcludeMultipleAccountsFromFeesAndDividends(address[] accounts, bool isExcluded);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event UpdateMarketingWallet(address indexed newAddress, address indexed oldAddress);
    event UpdateDonationWallet(address indexed newAddress, address indexed oldAddress);
    event UpdateDevelopmentWallet(address indexed newAddress, address indexed oldAddress);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        address indexed processor
    );

    constructor(
        address catsAddress_,
        address marketingWallet_,
        address donationWallet_,
        address developmentWallet_,
        address swapRouterAddress_,
        address[] memory privateSaleWallets_)
    ERC20("Catcoin Mama", "CATSMAMA")
    Ownable()
    AbstractDividends(){
        catsToken = IERC20(catsAddress_);
        maxWalletSize = initialSupply.mul(15).div(1000);
        privateSaleWallets = privateSaleWallets_;
        // uniswap initialization
        uniswapV2Router = IUniswapV2Router02(swapRouterAddress_);
        _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        automatedMarketMakerPairs[_uniswapV2Pair] = true;
        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        // enable features with initial fees
        setTaxDividend(200);
        switchAutoBurn(100, true);
        switchAutoSwapAndLiquify(100, 10_000_000_000 * 10 ** decimals(), true);
        setTaxMarketing(100);
        setTaxDonation(100);
        setTaxDevelopment(100);

        // exclude from fee.
        excludeAccountFromFee(address(this), true);
        excludeAccountFromFee(address(uniswapV2Router), true);
        setCanTradeInPresale(owner(), true);
        setCanTradeInPresale(address(this), true);
        setCanTradeInPresale(address(uniswapV2Router), true);

        // exclude from wallet cap.
        excludeAccountFromWalletCap(address(this), true);
        excludeAccountFromWalletCap(address(uniswapV2Router), true);
        excludeAccountFromWalletCap(address(marketingWallet), true);
        excludeAccountFromWalletCap(address(donationWallet), true);
        excludeAccountFromWalletCap(address(developmentWallet), true);
        excludeAccountFromWalletCap(address(owner()), true);


        // exclude dividends internal
        excludeFromDividends(address(this), true);
        excludeFromDividends(address(uniswapV2Router), true);
        excludeFromDividends(address(_uniswapV2Pair), true);
        excludeFromDividends(owner(), true);

        // configure wallets
        updateMarketingWallet(marketingWallet_);
        updateDonationWallet(donationWallet_);
        updateDevelopmentWallet(developmentWallet_);

        // exclude dividends wallets
        excludeFromDividends(marketingWallet, true);
        excludeFromDividends(donationWallet, true);
        excludeFromDividends(developmentWallet, true);
        excludeFromDividends(deadWallet, true);

        // Add initial supply to sender
        _mint(msg.sender, initialSupply);
    }

    // allow the contract to receive ETH
    receive() external payable {}

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Returns the address of this token and WETH pair.
     */
    function uniswapV2Pair() public view returns (address) {
        return _uniswapV2Pair;
    }

    /**
     * @dev Returns the current burn tax.
     */
    function taxBurn() public view returns (uint16) {
        return _halfTaxEnabled ? _taxBurn / 2 : _taxBurn;
    }

    /**
     * @dev Returns the current marketing tax.
     */
    function taxMarketing() public view returns (uint16) {
        return _halfTaxEnabled ? _taxMarketing / 2 : _taxMarketing;
    }

    /**
     * @dev Returns the current donation tax.
     */
    function taxDonation() public view returns (uint16) {
        return _halfTaxEnabled ? _taxDonation / 2 : _taxDonation;
    }

    /**
     * @dev Returns the current development tax.
     */
    function taxDevelopment() public view returns (uint16) {
        return _halfTaxEnabled ? _taxDevelopment / 2 : _taxDevelopment;
    }

    /**
     * @dev Returns the current liquify tax.
     */
    function taxLiquidity() public view returns (uint16) {
        return _halfTaxEnabled ? _taxLiquidity / 2 : _taxLiquidity;
    }

    /**
     * @dev Returns the current dividend tax.
     */
    function taxDividend() public view returns (uint16) {
        return _halfTaxEnabled ? _taxDividend / 2 : _taxDividend;
    }

    /**
    * @dev Returns true if auto burn feature is enabled.
     */
    function autoBurnEnabled() public view returns (bool) {
        return _autoBurnEnabled;
    }

    /**
    * @dev Returns true if half tax is enabled.
     */
    function halfTaxEnabled() public view returns (bool) {
        return _halfTaxEnabled;
    }

    /**
     * @dev Returns true if auto swap and liquify feature is enabled.
     */
    function autoSwapAndLiquifyEnabled() public view returns (bool) {
        return _autoSwapAndLiquifyEnabled;
    }

    /**
     * @dev Returns the threshold before swap and liquify.
     */
    function minTokensBeforeSwap() external view returns (uint256) {
        return _minTokensBeforeSwap;
    }

    /**
     * @dev Returns whether an account is excluded from fee.
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @dev Returns whether an account is excluded from wallet size cap.
     */
    function isExcludedFromWalletCap(address account) external view returns (bool) {
        return _isExcludedFromWalletCap[account];
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal override {
        if (owner() != address(0)) {
            excludeFromDividends(newOwner, true);
            setCanTradeInPresale(newOwner, true);
            excludeAccountFromWalletCap(newOwner, true);
        }
        super._transferOwnership(newOwner);
        excludeAccountFromFee(newOwner, true);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        if (!isPresaleComplete) {
            //turn transfer on to allow for whitelist
            require(canTradeInPresale[sender] || canTradeInPresale[recipient], "Trading is not allowed until presale is over!");
        }

        _beforeTokenTransfer(sender, recipient, amount);
        if (amount == 0) {
            _transferTokens(sender, recipient, 0);
            emit Transfer(sender, recipient, amount);
            return;
        }

        bool hasContracts = _isContract(sender) || _isContract(recipient);

        // process fees
        bool takeFee = (!_isExcludedFromFee[sender])
        && (!_isExcludedFromFee[recipient])
        && (hasContracts)
        && (!_inSwapAndLiquify)
        // liquidity removal
        && !(automatedMarketMakerPairs[sender] && recipient == address(uniswapV2Router));

        TokenFeeValues memory values = _getFeeValues(amount, takeFee);
        if (takeFee) {
            _transferTokens(sender, address(this), values.totalFee);
        }

        //Swapping is only possible if sender is not pancake pair,
        if (
            (hasContracts)
            && (!automatedMarketMakerPairs[sender])
            && (_autoSwapAndLiquifyEnabled)
            && (!_inSwapAndLiquify)
        ) _swapContractToken();

        // send tokens to recipient
        _transferTokens(sender, recipient, values.transferAmount);

        _afterTokenTransfer(sender, recipient, amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Simply performs a token transfer from sender to recipient
     */
    function _transferTokens(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        spendVestedTokens(sender, senderBalance, amount);
    unchecked {
        _balances[sender] = senderBalance - amount;
    }
        _balances[recipient] += amount;
        require(_isExcludedFromWalletCap[recipient] || _balances[recipient] <= maxWalletSize, "Recipient wallet exceeds the maximum size");
        setDividendBalance(sender, _balances[sender]);
        setDividendBalance(recipient, _balances[recipient]);
    }

    function _transferDividends(address recipient, uint256 amount) virtual internal override returns (bool){
        return catsToken.transfer(recipient, amount);
    }

    /**
     * @dev Swaps the contract token balance to BNB and distributes to wallets in the correct ratios.
     */
    function _swapContractToken() private {
        // preparation
        uint contractBalance = _balances[address(this)];
        bool overMinTokensBeforeSwap = contractBalance >= _minTokensBeforeSwap;
        if (!overMinTokensBeforeSwap) return;
        // start swapping
        _inSwapAndLiquify = true;

        uint256 totalTokensForLiquidity = _minTokensBeforeSwap * taxLiquidity() / _totalSwappableTax();
        uint256 liquidityTokenHalfAsETH = totalTokensForLiquidity / 2;
        uint256 liquidityTokenHalfAsCATSMAMA = totalTokensForLiquidity - liquidityTokenHalfAsETH;
        uint256 totalTokensToSwap = _minTokensBeforeSwap - liquidityTokenHalfAsCATSMAMA;
        // Contract's current ETH balance.
        uint256 initialETHBalance = address(this).balance;
        swapTokensForEth(totalTokensToSwap);
        uint256 swappedETHAmount = address(this).balance - initialETHBalance;
        SwapingETHValues memory values = getSwappingETHValues(swappedETHAmount);

        // process adding liquidity
        addLiquidity(values.liquidityETHAmount, liquidityTokenHalfAsCATSMAMA);

        // process sending ETH fees
        sendEth(marketingWallet, values.marketingETHAmount);
        sendEth(donationWallet, values.donationETHAmount);
        sendEth(developmentWallet, values.developmentETHAmount);

        // process CATS outputs
        uint256 prevCatsBalance = catsToken.balanceOf(address(this));
        swapEthForCats(values.burnETHAmount + values.dividendETHAmount);
        uint256 fullCatsBalance = catsToken.balanceOf(address(this));
        uint256 catsBalanceChange = fullCatsBalance - prevCatsBalance;
        if (fullCatsBalance > 0) {
            uint256 burnCats = catsBalanceChange.mul(values.burnETHAmount).div(values.burnETHAmount + values.dividendETHAmount);
            uint256 dividendCats = fullCatsBalance.sub(burnCats);
            if (burnCats > 0) catsToken.transfer(deadWallet, burnCats);
            _distributeDividends(dividendCats);

            // Process dividends
            if (_autoDividendProcessingEnabled) {
                (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = process(transfersPerBatch);
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, tx.origin);
            }
        }

        // start swapping
        _inSwapAndLiquify = false;
    }

    /**
     * @dev This method relies on extcodesize, which returns 0 for contracts in
     * construction, since the code is only stored at the end of the
     * constructor execution.
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
      * @dev Returns swappable total fee (all fees that should be swapped)
      * outputs 1% as 100, 1.5% as 150
     */
    function _totalSwappableTax() private view returns (uint16) {
        return taxLiquidity() + taxMarketing() + taxDonation() + taxDevelopment() + taxBurn() + taxDividend();
    }

    /**
     * @dev Excludes an account from fee.
      */
    function excludeAccountFromFee(address account, bool enable) internal {
        _isExcludedFromFee[account] = enable;
        emit ExcludeAccountFromFees(account);
    }

    /**
     * @dev Excludes an account from trade lock in presale.
      */
    function setCanTradeInPresale(address account, bool enable) public onlyOwner {
        canTradeInPresale[account] = enable;
    }

    /**
     * @dev Excludes an account from wallet size cap.
      */
    function excludeAccountFromWalletCap(address account, bool enable) public onlyOwner {
        _isExcludedFromWalletCap[account] = enable;
        emit ExcludeAccountFromWalletCap(account);
    }

    /**
     * @dev Switches half tax mode on & off
      */
    function switchHalfTax(bool enable) public onlyOwner {
        require(_halfTaxEnabled != enable, 'Already set!');
        _halfTaxEnabled = enable;
    }

    /**
     * @dev Excludes an account from fees and dividends.
      */
    function excludeAccountFromFeesAndDividends(address account, bool enable) external onlyOwner {
        excludeFromDividends(account, enable);
        excludeAccountFromFee(account, enable);
    }

    /**
     * @dev Excludes multiple accounts from fee.
      *
      * Emits a {ExcludeMultipleAccountsFromFees} event.
      */
    function excludeMultipleAccountsFromFeesAndDividends(
        address[] calldata accounts,
        bool enable
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = enable;
        }

        emit ExcludeMultipleAccountsFromFeesAndDividends(accounts, enable);
    }

    // Sends ETH into a specified account from this contract
    function sendEth(address account, uint256 amount) private returns (bool) {
        (bool success,) = account.call{value : amount}("");
        return success;
    }

    /**
     * @dev Swap `amount` tokens for ETH.
     *
     * Emits {Transfer} event. From this contract to the token and WETH Pair.
     */
    function swapTokensForEth(uint256 amount) private {
        // Generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // Swap tokens to ETH
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this), // this contract will receive the eth that were swapped from the token
            block.timestamp + 60 * 1000
        );
    }

    /**
     * @dev Swap `amount` tokens for CATS.
     */
    function swapEthForCats(uint256 amount) internal {
        // Generate the uniswap pair path of token -> cats
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(catsToken);

        // Swap tokens to ETH
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value : amount}(
            0,
            path,
            address(this), // this contract will receive the cats that were swapped from the token
            block.timestamp + 60 * 1000
        );
    }

    /**
     * @dev Add `ethAmount` of ETH and `tokenAmount` of tokens to the LP.
     * Depends on the current rate for the pair between this token and WETH,
     * `ethAmount` and `tokenAmount` might not match perfectly.
     * Dust(leftover) ETH or token will be refunded to this contract
     * (usually very small quantity).
     *
     * Emits {Transfer} event. From this contract to the token and WETH Pai.
     */
    function addLiquidity(uint256 ethAmount, uint256 tokenAmount) private {
        // Add the ETH and token to LP.
        // The LP tokens will be sent to burnAccount.
        // No one will have access to them, so the liquidity will be locked forever.
        uniswapV2Router.addLiquidityETH{value : ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadWallet, // the LP is sent to burnAccount.
            block.timestamp + 60 * 1000
        );
    }

    /**
     * @dev Returns fees amount in tokens in each tax category
     */
    function _getFeeValues(uint256 amount, bool deductTransferFee) private view returns (TokenFeeValues memory) {
        TokenFeeValues memory values;
        values.amount = amount;

        if (!deductTransferFee) {
            values.transferAmount = values.amount;
        } else {
            // fee to inside the contract
            values.liquifyFee = _calculateTax(values.amount, taxLiquidity());
            values.marketingFee = _calculateTax(values.amount, taxMarketing());
            values.donationFee = _calculateTax(values.amount, taxDonation());
            values.developmentFee = _calculateTax(values.amount, taxDevelopment());
            values.burnFee = _calculateTax(values.amount, taxBurn());
            values.dividendFee = _calculateTax(values.amount, taxDividend());
            values.totalFee = values.liquifyFee + values.marketingFee + values.donationFee + values.developmentFee + values.dividendFee + values.burnFee;

            // No fees to outside the contract in catsmama v2

            // amount after fee
            values.transferAmount = values.amount - values.totalFee;
        }

        return values;
    }

    /**
     * @dev Returns fee based on `amount` and `taxRate`
     */
    function _calculateTax(uint256 amount, uint16 tax) private pure returns (uint256) {
        return amount * tax / (10 ** 2) / (10 ** 2);
    }

    /**
     * @dev Returns swappable fee amounts in ETH.
     */
    function getSwappingETHValues(uint256 ethAmount) public view returns (SwapingETHValues memory) {
        SwapingETHValues memory values;
        uint16 totalTax = (taxLiquidity() / 2) + taxMarketing() + taxDonation() + taxDevelopment() + taxBurn() + taxDividend();

        values.marketingETHAmount = _calculateSwappableTax(ethAmount, taxMarketing(), totalTax);
        values.donationETHAmount = _calculateSwappableTax(ethAmount, taxDonation(), totalTax);
        values.developmentETHAmount = _calculateSwappableTax(ethAmount, taxDevelopment(), totalTax);
        values.burnETHAmount = _calculateSwappableTax(ethAmount, taxBurn(), totalTax);
        values.dividendETHAmount = _calculateSwappableTax(ethAmount, taxDividend(), totalTax);
        // remaining ETH is as the liquidity half
        values.liquidityETHAmount = ethAmount - (values.marketingETHAmount + values.developmentETHAmount + values.donationETHAmount + values.burnETHAmount + values.dividendETHAmount);

        return values;
    }

    /**
     * @dev Returns ETH swap amount based on tax & total tax
     */
    function _calculateSwappableTax(uint256 amount, uint16 tax, uint16 totalTax) private pure returns (uint256) {
        return (amount * tax) / totalTax;
    }

    /*
        Owner functions
    */

    /**
      * @dev Ends the presale and launches the open sale
     */
    function completePresale() public onlyOwner {
        require(!isPresaleComplete, "Presale already completed!");
        isPresaleComplete = true;
        presaleCompletedTimestamp = block.timestamp;
    }

    /**
      * @dev Sets vesting enabled for the private sale wallets
     */
    function vestPrivateSaleWallets() external {
        require(!isPresaleComplete, 'Cannot vest after token presale!');
        require(!vestingPerformed, 'Vesting is already performed.');
        for (uint i = 0; i < privateSaleWallets.length; i++) {
            _vestAccount(privateSaleWallets[i], true);
        }
        vestingPerformed = true;
    }

    /**
      * @dev Sets vesting on an account
     */
    function _vestAccount(address account, bool enable) private {
        if (enable) {
            VestInfo memory vestInfo = VestInfo(
            {vestAmount : balanceOf(account), enabled : true});
            _vests[account] = vestInfo;
        } else {
            _vests[account].enabled = false;
        }
    }

    /**
      * @dev Verifies
     */
    function spendVestedTokens(address account, uint256 senderBalance, uint256 amount) internal view {
        if (!_vests[account].enabled || !isPresaleComplete) {
            return;
        }
        VestInfo memory vestInfo = _vests[account];
        uint256 balanceLocked = 0;
        uint256 elapsedTime = block.timestamp - presaleCompletedTimestamp;
        if (elapsedTime >= 4 weeks) {
            balanceLocked = 0;
        } else if (elapsedTime >= 3 weeks) {
            balanceLocked = vestInfo.vestAmount.mul(25).div(100);
        } else if (elapsedTime >= 2 weeks) {
            balanceLocked = vestInfo.vestAmount.mul(50).div(100);
        } else {
            balanceLocked = vestInfo.vestAmount.mul(75).div(100);
        }
        require(senderBalance - amount >= balanceLocked, 'Maximum spend amount exceeded during vesting cycle');
    }

    /**
     * @dev Adds a given pair into automated market maker pairs map
     */
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "AMM pair has been assigned!");
        automatedMarketMakerPairs[pair] = value;
        excludeFromDividends(pair, value);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    /**
     * @dev Switches auto processing token burns on each transaction
     */
    function switchAutoBurn(uint16 taxBurn_, bool enable) public onlyOwner {
        if (!enable) {
            require(_autoBurnEnabled, "Already disabled.");
            setTaxBurn(0);
            _autoBurnEnabled = false;

            emit DisabledAutoBurn();
            return;
        }
        require(!_autoBurnEnabled, "Already enabled.");
        require(taxBurn_ > 0, "Tax must be greater than 0.");

        _autoBurnEnabled = true;
        setTaxBurn(taxBurn_);

        emit EnabledAutoBurn();
    }

    /**
       * @dev Switches auto processing dividend processing on each transaction
     */
    function switchAutoDividendProcessing(bool enable) public onlyOwner {
        require(_autoDividendProcessingEnabled != enable, "Already set");
        _autoDividendProcessingEnabled = enable;
    }

    /**
     * @dev Sets max tx count for auto processing on each transaction
     */
    function setMaxDividendTransfersPerBatch(uint maxTransfers) public onlyOwner {
        require(transfersPerBatch != maxTransfers, "Already set");
        transfersPerBatch = maxTransfers;
    }

    /**
     * @dev Switches auto processing swapping contract token balance into BNB on each transaction
     */
    function switchAutoSwapAndLiquify(uint16 taxLiquify_, uint256 minTokensBeforeSwap_, bool enable) public onlyOwner {
        if (!enable) {
            require(_autoSwapAndLiquifyEnabled, "Already disabled.");
            setTaxLiquidity(0);
            _autoSwapAndLiquifyEnabled = false;
            emit DisabledAutoSwapAndLiquify();
            return;
        }

        require(!_autoSwapAndLiquifyEnabled, "Already enabled.");
        require(taxLiquify_ > 0, "Tax must be greater than 0.");

        _minTokensBeforeSwap = minTokensBeforeSwap_;
        _autoSwapAndLiquifyEnabled = true;
        setTaxLiquidity(taxLiquify_);

        emit EnabledAutoSwapAndLiquify();
    }

    /**
     * @dev Updates `_minTokensBeforeSwap`
      *
      * Emits a {MinTokensBeforeSwap} event.
      *
      * Requirements:
      *
      * - `minTokensBeforeSwap_` must be less than _currentSupply.
      */
    function setMinTokensBeforeSwap(uint256 minTokensBeforeSwap_) public onlyOwner {
        require(minTokensBeforeSwap_ < _totalSupply, "Must be lower than current supply.");

        uint256 previous = _minTokensBeforeSwap;
        _minTokensBeforeSwap = minTokensBeforeSwap_;

        emit MinTokensBeforeSwapUpdated(previous, _minTokensBeforeSwap);
    }

    function ensureTotalFeeBounds() internal view {
        uint16 totalTax = taxBurn() +
        taxMarketing() +
        taxDonation() +
        taxDevelopment() +
        taxDividend() +
        taxLiquidity();
        require(totalTax <= 900, 'Total tax must be below 9%');
    }

    /**
      * @dev Updates taxBurn
      *
      * Emits a {TaxBurnUpdate} event.
      *
      * Requirements:
      *
      * - auto burn feature must be enabled.
      * - total tax rate must be less than 100%.
      */
    function setTaxBurn(uint16 taxBurn_) public onlyOwner {
        require(_autoBurnEnabled, "Auto burn not enabled");
        require(taxBurn_ <= 500, 'Must be below 5%');

        uint16 previousTax = taxBurn();
        _taxBurn = taxBurn_;

        ensureTotalFeeBounds();
        emit TaxBurnUpdate(previousTax, taxBurn_);
    }

    /**
      * @dev Updates taxDividend
      *
      * Emits a {TaxDividendUpdate} event.
      */
    function setTaxDividend(uint16 taxDividend_) public onlyOwner {
        require(taxDividend_ <= 600, 'Must be below 6%');
        require(taxDividend_ >= 200, 'Must be above 2%');
        uint16 previousTax = taxDividend();
        _taxDividend = taxDividend_;

        ensureTotalFeeBounds();
        emit TaxDividendUpdate(previousTax, taxDividend_);
    }

    /**
      * @dev Updates taxMarketing
      *
      * Emits a {TaxMarketingUpdate} event.
      *
      * Requirements:
      *
      * - total tax rate must be less than 100%.
      */
    function setTaxMarketing(uint16 taxMarketing_) public onlyOwner {
        require(taxMarketing_ <= 500, 'Must be below 5%');
        require(taxMarketing_ >= 100, 'Must be above 1%');
        uint16 previousTax = taxMarketing();
        _taxMarketing = taxMarketing_;

        ensureTotalFeeBounds();
        emit TaxMarketingUpdate(previousTax, taxMarketing_);
    }

    /**
      * @dev Updates taxDonation
      *
      * Emits a {TaxDonationUpdate} event.
      *
      * Requirements:
      *
      * - total tax rate must be less than 100%.
      */
    function setTaxDonation(uint16 taxDonation_) public onlyOwner {
        require(taxDonation_ <= 500, 'Must be below 5%');
        require(taxDonation_ >= 100, 'Must be above 1%');
        uint16 previousTax = taxDonation();
        _taxDonation = taxDonation_;

        ensureTotalFeeBounds();
        emit TaxDonationUpdate(previousTax, taxDonation_);
    }

    /**
      * @dev Updates taxDevelopment
      *
      * Emits a {TaxDevelopmentUpdate} event.
      *
      * Requirements:
      *
      * - total tax rate must be less than 100%.
      */
    function setTaxDevelopment(uint16 taxDevelopment_) public onlyOwner {
        require(taxDevelopment_ <= 500, 'Must be below 5%');
        uint16 previousTax = taxDevelopment();
        _taxDevelopment = taxDevelopment_;

        ensureTotalFeeBounds();
        emit TaxDevelopmentUpdate(previousTax, taxDevelopment_);
    }

    /**
      * @dev Updates taxLiquify
      *
      * Emits a {TaxLiquifyUpdate} event.
      *
      * Requirements:
      *
      * - auto swap and liquify feature must be enabled.
      * - total tax rate must be less than 100%.
      */
    function setTaxLiquidity(uint16 taxLiquify_) public onlyOwner {
        require(_autoSwapAndLiquifyEnabled, "Auto swap and liquify not enabled");
        require(taxLiquify_ <= 500, 'Must be below 5%');

        uint16 previousTax = taxLiquidity();
        _taxLiquidity = taxLiquify_;

        ensureTotalFeeBounds();
        emit TaxLiquifyUpdate(previousTax, taxLiquify_);
    }

    /**
     * @dev Sets the wallet for the marketing BNB charged for Cats applications & games.
     */
    function updateMarketingWallet(address newAddress) public onlyOwner {
        require(newAddress != address(marketingWallet), "Already set!");
        setCanTradeInPresale(newAddress, true);
        excludeAccountFromFee(newAddress, true);
        excludeFromDividends(newAddress, true);
        emit UpdateMarketingWallet(newAddress, address(marketingWallet));
        marketingWallet = newAddress;
    }

    /**
     * @dev Sets the wallet for the donation BNB charged for Cats applications & games.
     */
    function updateDonationWallet(address newAddress) public onlyOwner {
        require(newAddress != address(donationWallet), "Already set!");
        setCanTradeInPresale(newAddress, true);
        excludeAccountFromFee(newAddress, true);
        excludeFromDividends(newAddress, true);
        emit UpdateDonationWallet(newAddress, address(donationWallet));
        donationWallet = newAddress;
    }

    /**
     * @dev Sets the wallet for the development BNB charged for Cats applications & games.
     */
    function updateDevelopmentWallet(address newAddress) public onlyOwner {
        require(newAddress != address(developmentWallet), "Already set!");
        setCanTradeInPresale(newAddress, true);
        excludeAccountFromFee(newAddress, true);
        excludeFromDividends(newAddress, true);
        emit UpdateDevelopmentWallet(newAddress, address(developmentWallet));
        developmentWallet = newAddress;
    }

    function claimDividends() external {
        uint256 withdrawable = _prepareCollect(msg.sender);
        require(withdrawable > 0, 'No withdrawable dividends available');
        catsToken.transfer(msg.sender, withdrawable);
    }
}
