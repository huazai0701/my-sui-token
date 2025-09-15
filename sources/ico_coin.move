module multi_token_package::ico_coin {
    // --- 模块引入 ---
    use std::ascii;
    use std::string::{Self, String};
    use sui::{
        coin::{Self, Coin, CoinMetadata},
        event,
        url::Url
    };

    // --- 代币类型定义 ---
    public struct ICO has drop {}
    
    // One-time witness type for init function
    public struct ICO_COIN has drop {}

    // --- 事件定义 ---
    public struct TokenCreatedEvent has copy, drop {
        total_supply: u64,
        initial_holders: vector<address>,
        decimals: u8,
        symbol: String,
        name: String,
    }

    // Web3标准事件
    public struct TransferEvent has copy, drop {
        from: address,
        to: address,
        value: u64,
        timestamp: u64
    }

    public struct BurnEvent has copy, drop {
        burner: address,
        amount: u64,
        timestamp: u64
    }

    public struct BatchTransferEvent has copy, drop {
        sender: address,
        recipient_count: u64,
        total_amount: u64,
        timestamp: u64
    }
    
    // --- 常量定义 ---
    const E_INVALID_ALLOCATION: u64 = 0;
    const E_INSUFFICIENT_BALANCE: u64 = 1001;
    const E_INVALID_AMOUNT: u64 = 1005;

    // --- 合约初始化函数 ---
    fun init(witness: ICO_COIN, ctx: &mut sui::tx_context::TxContext) {
        let total_supply: u64 = 10_000_000_000000000; // 1000万代币，9位小数
        let sender = sui::tx_context::sender(ctx);

        // 设置代币图标URL
        let icon_url = std::option::some(sui::url::new_unsafe_from_bytes(
            b"https://magenta-quickest-fly-406.mypinata.cloud/ipfs/bafkreiatacmygy63ulv6r5gzqs4ic6l7fucsavftuzwhrquak6mldfax7m"
        ));

        // 创建代币
        let (mut treasury_cap, metadata) = coin::create_currency(
            witness,
            9u8, // 9位小数
            b"Zeo", // 代币符号
            b"Zeo Protocol", // 代币名称
            b"Zeo is a utility token built on Sui blockchain with advanced features including batch transfers, burn mechanisms, and Web3 wallet compatibility. Zeo serves as the native utility token for the Zeo ecosystem.", // 详细描述
            icon_url,
            ctx,
        );

        // 合理的代币分配 - 分配给三个不同地址
        let team_allocation = 2_000_000_000000000; // 20% 给团队
        let community_allocation = 3_000_000_000000000; // 30% 给社区
        let liquidity_allocation = 5_000_000_000000000; // 50% 给流动性

        // 预定义地址
        const TEAM_ADDRESS: address = @0x8f6cb62de26e16d10409921140534d6c1f31ec136c6885250586d9f0fb352160;
        const COMMUNITY_ADDRESS: address = @0xe304a8a53a84d4f63a3a8c86376d13d81e205eb75cceca5bf388630c002e1070;
        const LIQUIDITY_ADDRESS: address = @0xb26f312156c464b327c1bb76775d20f8318227552689c0fcbc0f6e31a1389349;

        // 分配代币
        let team_coin = coin::mint(&mut treasury_cap, team_allocation, ctx);
        let community_coin = coin::mint(&mut treasury_cap, community_allocation, ctx);
        let liquidity_coin = coin::mint(&mut treasury_cap, liquidity_allocation, ctx);

        // 转移代币到指定地址
        sui::transfer::public_transfer(team_coin, TEAM_ADDRESS); // 团队部分
        sui::transfer::public_transfer(community_coin, COMMUNITY_ADDRESS); // 社区部分
        sui::transfer::public_transfer(liquidity_coin, LIQUIDITY_ADDRESS); // 流动性部分

        // 销毁铸币权（确保固定供应量）
        sui::transfer::public_transfer(treasury_cap, @0x0);
        
        // 转移元数据给发布者
        sui::transfer::public_transfer(metadata, sender);

        // 触发代币创建事件
        let mut holders = vector::empty<address>();
        vector::push_back(&mut holders, TEAM_ADDRESS);
        vector::push_back(&mut holders, COMMUNITY_ADDRESS);
        vector::push_back(&mut holders, LIQUIDITY_ADDRESS);

        event::emit(TokenCreatedEvent {
            total_supply,
            initial_holders: holders,
            decimals: 9u8,
            symbol: string::utf8(b"Zeo"),
            name: string::utf8(b"Zeo Protocol"),
        });
    }

    // === 查询函数 ===
    
    /// 获取总供应量
    public fun total_supply(): u64 {
        10_000_000_000000000
    }

    /// 获取代币精度
    public fun get_decimals(metadata: &CoinMetadata<ICO>): u8 {
        coin::get_decimals(metadata)
    }

    /// 获取代币符号
    public fun get_symbol(metadata: &CoinMetadata<ICO>): String {
        let symbol_ascii = coin::get_symbol(metadata);
        string::utf8(ascii::into_bytes(symbol_ascii))
    }

    /// 获取代币名称
    public fun get_name(metadata: &CoinMetadata<ICO>): String {
        coin::get_name(metadata)
    }

    /// 获取代币图标URL
    public fun get_icon_url(metadata: &CoinMetadata<ICO>): std::option::Option<Url> {
        coin::get_icon_url(metadata)
    }

    /// 获取代币描述
    public fun get_description(metadata: &CoinMetadata<ICO>): String {
        coin::get_description(metadata)
    }

    /// 获取代币余额
    public fun balance_of(coin: &Coin<ICO>): u64 {
        coin::value(coin)
    }

    // === 交易函数 ===

    /// 标准转移函数（Web3钱包兼容）
    public fun transfer(coin: Coin<ICO>, recipient: address, ctx: &mut sui::tx_context::TxContext) {
        let amount = coin::value(&coin);
        let sender = sui::tx_context::sender(ctx);
        
        sui::transfer::public_transfer(coin, recipient);
        
        // 触发转移事件
        event::emit(TransferEvent {
            from: sender,
            to: recipient,
            value: amount,
            timestamp: sui::tx_context::epoch_timestamp_ms(ctx)
        });
    }

    /// 转移代币（保持向后兼容）
    public fun transfer_coin(coin: Coin<ICO>, recipient: address, _ctx: &mut sui::tx_context::TxContext) {
        sui::transfer::public_transfer(coin, recipient);
    }

    /// 批量转移（减少Gas费用）
    public fun batch_transfer(
        coin: &mut Coin<ICO>, 
        recipients: vector<address>, 
        amounts: vector<u64>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        // 输入验证
        assert!(vector::length(&recipients) == vector::length(&amounts), E_INVALID_AMOUNT);
        assert!(!vector::is_empty(&recipients), E_INVALID_AMOUNT);
        
        let mut i = 0;
        let mut total_amount = 0;
        while (i < vector::length(&recipients)) {
            let recipient = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);
            
            // 验证金额
            assert!(amount > 0, E_INVALID_AMOUNT);
            assert!(amount <= coin::value(coin), E_INSUFFICIENT_BALANCE);
            
            let transfer_coin = coin::split(coin, amount, ctx);
            sui::transfer::public_transfer(transfer_coin, recipient);
            
            total_amount = total_amount + amount;
            i = i + 1;
        };
        
        // 触发批量转移事件
        event::emit(BatchTransferEvent {
            sender: sui::tx_context::sender(ctx),
            recipient_count: vector::length(&recipients),
            total_amount,
            timestamp: sui::tx_context::epoch_timestamp_ms(ctx)
        });
    }

    /// 分割代币
    #[allow(lint(self_transfer))]
    public fun split_coin(coin: &mut Coin<ICO>, amount: u64, ctx: &mut sui::tx_context::TxContext) {
        let new_coin = coin::split(coin, amount, ctx);
        sui::transfer::public_transfer(new_coin, sui::tx_context::sender(ctx));
    }

    /// 合并代币
    public fun merge_coins(coin1: &mut Coin<ICO>, coin2: Coin<ICO>) {
        coin::join(coin1, coin2);
    }

    /// 销毁代币
    public fun burn_coin(coin: Coin<ICO>, ctx: &mut sui::tx_context::TxContext) {
        let amount = coin::value(&coin);
        
        // 触发销毁事件
        event::emit(BurnEvent {
            burner: sui::tx_context::sender(ctx),
            amount,
            timestamp: sui::tx_context::epoch_timestamp_ms(ctx)
        });
        
        // 销毁代币（将Coin放入零Balance中）
        let mut balance = sui::balance::zero<ICO>();
        coin::put(&mut balance, coin);
        sui::balance::join(&mut balance, sui::balance::zero<ICO>());
        // 销毁balance
        sui::balance::destroy_zero(balance);
    }

    /// 批量销毁
    public fun batch_burn(mut coins: vector<Coin<ICO>>) {
        let mut balance = sui::balance::zero<ICO>();
        while (!vector::is_empty(&coins)) {
            let coin = vector::pop_back(&mut coins);
            // 销毁代币（将Coin放入Balance中）
            coin::put(&mut balance, coin);
        };
        // 将Balance与零Balance合并（销毁）
        sui::balance::join(&mut balance, sui::balance::zero<ICO>());
        // 销毁balance
        sui::balance::destroy_zero(balance);
        // 销毁空的coins向量
        vector::destroy_empty(coins);
    }

    /// 获取代币元数据信息（用于前端显示）
    public fun get_coin_info(metadata: &CoinMetadata<ICO>): (String, String, u8, String, std::option::Option<Url>) {
        (
            get_name(metadata),
            get_symbol(metadata),
            get_decimals(metadata),
            get_description(metadata),
            get_icon_url(metadata)
        )
    }

    // === Web3钱包优化接口 ===

    /// 获取代币显示信息（钱包显示用）
    public fun get_token_display_info(): (String, String, u8, String, String) {
        (
            string::utf8(b"Zeo Protocol"), // 名称
            string::utf8(b"Zeo"),       // 符号
            9u8,                        // 精度
            string::utf8(b"10000000"),  // 总供应量
            string::utf8(b"https://magenta-quickest-fly-406.mypinata.cloud/ipfs/bafkreiatacmygy63ulv6r5gzqs4ic6l7fucsavftuzwhrquak6mldfax7m") // 图标
        )
    }

    /// 轻量级查询（移动端优化）
    public fun get_lightweight_info(): (String, String, u8) {
        (
            string::utf8(b"Zeo"),
            string::utf8(b"Zeo Protocol"),
            9u8
        )
    }

    /// 预估Gas费用
    public fun estimate_gas_cost(_operation: u8, _amount: u64): u64 {
        1000000 // 默认gas费用
    }

    /// 获取实时代币信息
    public fun get_realtime_info(): (u64, u64, u64, u64) {
        (
            10_000_000_000000000, // 总供应量
            10_000_000_000000000, // 流通量
            1,                    // 持有者数
            0                     // 24小时交易量
        )
    }

    /// 获取错误消息
    public fun get_error_message(_error_code: u64): String {
        string::utf8(b"Unknown error")
    }
}
