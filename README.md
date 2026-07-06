# MT5 Position Sizer Tool

This is a professional and interactive Position Sizer Expert Advisor (EA) for **MetaTrader 5 (MT5)**. It provides a visual, on-chart control panel with draggable lines for Entry, Stop Loss (SL), and Take Profit (TP), automatically calculating the proper lot size based on your specified risk.

---

## Features (मुख्य विशेषताएं)

1. **Draggable Lines**:
   - **Entry Line (Blue)**: Set your Entry price (active for Limit and Stop orders). Locked to Bid/Ask in Market mode.
   - **Stop Loss Line (Red)**: Drag to set Stop Loss.
   - **Take Profit Line (Green)**: Drag to set Take Profit.
2. **Order Types**:
   - **Market Position**: Instantly executes at current Bid/Ask.
   - **Limit Position**: Places a Buy Limit or Sell Limit order.
   - **Stop Position**: Places a Buy Stop or Sell Stop order.
3. **Flexible Risk Management**:
   - **Percentage Risk (`%`)**: Risk a percentage of your account balance (e.g. 1%, 2%).
   - **Fixed Cash Risk (`$`)**: Risk a fixed amount of cash (e.g. $100, $500).
4. **Dynamic Details**:
   - Live lot calculation based on the distance between Entry and SL.
   - Display of potential Risk (loss) and Reward (profit) in account deposit currency.
   - Dynamic Risk to Reward (R:R) ratio display.
5. **Interactive Controls**:
   - Change direction (BUY/SELL) with one click. Switching direction automatically mirrors/swaps your SL and TP lines to keep the trade valid!
   - Change order type (MARKET/LIMIT/STOP) instantly.
   - Double-click and drag the lines to update calculations in real-time.
   - Input custom risk values directly from the chart edit box.

---

## Installation & Setup Instructions (इंस्टॉलेशन निर्देश)

### Step 1: Copy Code to MT5 MetaEditor
1. Open **MetaTrader 5**.
2. Press **F4** on your keyboard (or go to `Tools` -> `MQL5 Wizard / MetaEditor`) to open the **MetaEditor**.
3. In the MetaEditor, right-click on the `Experts` folder in the Navigator panel and click **New File**.
4. Choose **Expert Advisor (template)** and click **Next**.
5. Name the file **`MT5_PositionSizer`** and click **Next**, then **Finish**.
6. Delete everything in the newly created file and copy-paste the entire contents of `MT5_PositionSizer.mq5` into it.
7. Click the **Compile** button at the top toolbar (or press **F7**). Ensure there are no errors in the toolbox at the bottom.

---

### Step 2: Attach to Chart
1. Return to the **MetaTrader 5** terminal.
2. In the **Navigator** window (Press `Ctrl+N` if not visible), expand the **Experts** folder.
3. Find **`MT5_PositionSizer`**, drag and drop it onto the chart you want to trade.
4. In the EA properties popup:
   - Go to the **Common** tab and check **"Allow Algo Trading"**.
   - In the **Inputs** tab, you can set your default Magic Number, Risk Mode, Default SL/TP, and Slippage.
   - Click **OK**.

---

### Step 3: Enable Auto Trading
1. Click the **"Algo Trading"** button in the top menu bar of MT5. It should turn **Green** (indicating active trading is allowed).
2. The panel will appear in the top-left corner of the chart, along with three draggable lines (Entry, Stop Loss, Take Profit).

---

## How to Use (कैसे इस्तेमाल करें)

1. **Direction**: Click the **BUY** / **SELL** button on the panel to change trade direction. The lines will swap to keep your SL/TP logical.
2. **Order Type**: Toggle the **Order Type** button between `MARKET`, `LIMIT`, and `STOP`.
   - In `MARKET` mode, the blue Entry line stays locked to the current price.
   - In `LIMIT` or `STOP` modes, you can drag the blue Entry line to specify your desired entry.
3. **Risk Mode**: Click the **Risk Mode** button to switch between `% Percentage` and `$ Fixed Cash`.
4. **Risk Value**: Double-click the edit box next to "Risk Value", type your desired risk value (e.g. `1.5` for 1.5% or `150` for $150), and press **Enter**.
5. **Drag Lines**: Double-click the SL (Red), TP (Green), or Entry (Blue) lines to select them, and drag them to your technical levels on the chart.
6. **Execution**: Click **PLACE ORDER**. A confirmation window will pop up showing the trade details. Confirm to send the order to the market.

---

### Hindi Translation (हिंदी निर्देश)

1. **MT5 Open Karein** aur **F4** dabakar MetaEditor kholein.
2. `Experts` folder par right-click karke `New File` banayein aur usme `MT5_PositionSizer.mq5` ka code paste karein.
3. **Compile** (F7) dabayein.
4. MT5 me wapas aakar **Navigator** (Ctrl+N) se `MT5_PositionSizer` ko chart par drag aur drop karein.
5. Setup popup me **Allow Algo Trading** check karein.
6. Chart par controls aur lines aa jayengi:
   - **Buy / Sell toggle**: Ek click me trade ki direction change karein.
   - **Market / Limit / Stop toggle**: Order type select karein.
   - **Risk Input**: Panel par risk value direct edit kar sakte hain.
   - **Drag Lines**: Chart par lines ko drag karke position size calculate karein aur **Place Order** click karke execute karein.
