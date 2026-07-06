# MT5 Position Sizer Tool

An advanced, interactive Position Sizer Expert Advisor (EA) for **MetaTrader 5 (MT5)**. It provides a visual, on-chart control panel with draggable lines for Entry, Stop Loss (SL), and Take Profit (TP), automatically calculating the optimal lot size based on your account balance and risk preferences.

---

## Key Features

1. **Draggable Chart Lines**:
   - **Entry Line (Blue)**: Position the entry price for Pending orders (Limit/Stop). Locked to current Bid/Ask in Market mode.
   - **Stop Loss Line (Red)**: Drag to set the Stop Loss level.
   - **Take Profit Line (Green)**: Drag to set the Take Profit level.
2. **Order Types Supported**:
   - **Market Orders**: Instant execution at the current Ask (for BUY) or Bid (for SELL).
   - **Limit Orders**: Places Buy Limit or Sell Limit orders.
   - **Stop Orders**: Places Buy Stop or Sell Stop orders.
3. **Flexible Risk Management**:
   - **Percentage Risk (`%`)**: Risk a custom percentage of your account balance (e.g. 1.0%, 2.5%).
   - **Fixed Cash Risk (`$`)**: Risk a fixed dollar amount (e.g. $100, $500).
4. **Dynamic Trade Metrics**:
   - Real-time lot size calculation based on the distance between the Entry and Stop Loss lines.
   - Live profit/loss metrics for both Risk (SL) and Reward (TP) displayed in your deposit currency.
   - Auto-updating Risk-to-Reward (R:R) ratio indicator.
5. **Interactive Controls**:
   - **Direction Toggle (BUY/SELL)**: Switch trade direction with a single click. The EA automatically mirrors/swaps your SL and TP lines to keep the trade valid.
   - **Order Type Toggle**: Change execution style instantly (Market, Limit, or Stop).
   - **Risk Input Box**: Edit your risk value directly on the chart without opening the EA settings menu.
   - **Minimize Button**: Collapse the panel into a compact header bar to save chart space.
   - **Hide/Show Lines Toggle**: Instantly hide SL/TP/Entry lines from the chart while preserving their prices.
6. **Robust UI Performance**:
   - **Anti-Focus Loss**: Automatically pauses background tick redraws while you are typing to prevent cursor kicking.
   - **Click Priority (Z-Order)**: Layered Z-ordering ensures backgrounds never intercept button or input clicks.
   - **Timeframe Persistence**: All prices, inputs, and states (minimize/lines toggle) persist when switching chart timeframes.

---

## Installation & Setup Instructions

### Step 1: Copy Code to MT5 MetaEditor
1. Launch **MetaTrader 5**.
2. Press **F4** on your keyboard (or navigate to `Tools` -> `MQL5 Wizard / MetaEditor`) to open **MetaEditor**.
3. In the Navigator panel on the left, right-click on the `Experts` folder and select **New File**.
4. Choose **Expert Advisor (template)** and click **Next**.
5. Name the file **`MT5_PositionSizer`** and click **Next**, then **Finish**.
6. Delete the default generated code template, copy the entire contents of `MT5_PositionSizer.mq5`, and paste it into the file.
7. Click the **Compile** button in the top toolbar (or press **F7**). Verify that the build succeeds without errors.

---

### Step 2: Attach to Chart
1. Return to the **MetaTrader 5** terminal.
2. In the **Navigator** window (Press `Ctrl+N` if hidden), expand the **Experts** folder.
3. Find **`MT5_PositionSizer`**, then drag and drop it onto the chart of the symbol you wish to trade.
4. In the properties popup window:
   - Select the **Common** tab and check **"Allow Algo Trading"**.
   - Go to the **Inputs** tab to adjust defaults (Magic Number, Risk Mode, Default SL/TP Points, and Slippage).
   - Click **OK**.

---

### Step 3: Enable Automated Trading
1. Click the **"Algo Trading"** button in the MT5 top menu bar. The icon should turn **Green** (indicating active trading is allowed).
2. The control panel will appear in the top-left corner of the chart, along with the Entry, Stop Loss, and Take Profit lines.

---

## How to Use the Dashboard

1. **Direction**: Click the **BUY** / **SELL** button on the panel to change trade direction. The chart lines will mirror/swap automatically to maintain a valid setup.
2. **Order Type**: Toggle the **Execution Type** button between `MARKET`, `LIMIT`, and `STOP`.
   - In `MARKET` mode, the blue Entry line stays locked to the current price.
   - In `LIMIT` or `STOP` modes, double-click and drag the blue Entry line to specify your entry price.
3. **Risk Mode**: Click the **Risk Mode** button to toggle calculations between `% BALANCE` and `$ CASH VALUE`.
4. **Risk Value**: Double-click the input field next to "Risk Value", type your desired risk (e.g. `1.50` for 1.5% or `150.00` for $150), and press **Enter** (or click elsewhere on the chart) to apply.
5. **Drag Lines**: Double-click the SL (Red), TP (Green), or Entry (Blue) lines to select them, and drag them to your technical levels on the chart.
6. **Toggle Lines**: Click the **Chart Lines** button to switch between `VISIBLE` and `HIDDEN` if you want to clean up your chart.
7. **Minimize**: Click the `[-]` / `[+]` button in the top-right corner of the header to collapse/expand the panel.
8. **Execution**: Click **PLACE ORDER**. A trade confirmation window will pop up showing the final trade details. Confirm to send the order to the market.
