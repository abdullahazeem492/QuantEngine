const express = require('express');
const cors = require('cors');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const axios = require('axios');

const app = express();
app.use(cors());
app.use(express.json());

// Serve static frontend files from the /gui directory
app.use(express.static(path.join(__dirname, '..', 'gui')));

const DATA_DIR = path.join(__dirname, '..', 'data');
if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR);
}

// Available assets for the demo
const SUPPORTED_ASSETS = [
    { symbol: 'BTCUSDT', name: 'Bitcoin' },
    { symbol: 'ETHUSDT', name: 'Ethereum' },
    { symbol: 'BNBUSDT', name: 'Binance Coin' },
    { symbol: 'SOLUSDT', name: 'Solana' },
    { symbol: 'ADAUSDT', name: 'Cardano' },
    { symbol: 'DOTUSDT', name: 'Polkadot' },
    { symbol: 'MATICUSDT', name: 'Polygon' }
];

// --- VIVA CONFIGURATION ---
const MPI_NODES = 1; // Set to 4 or 8 to demonstrate speedup
// -------------------------

// Set to false to enable real execution in WSL2
const MOCK_RESPONSE = false;

app.get('/api/assets', (req, res) => {
    res.json(SUPPORTED_ASSETS);
});

// Fetch historical data from Binance and save as CSV for the C++ engine
app.get('/api/fetch-data/:symbol', async (req, res) => {
    const { symbol } = req.params;
    const interval = '1h'; // Hourly data
    const limit = 1000;

    try {
        console.log(`[Data Fetch] Fetching ${limit} ${interval} bars for ${symbol}...`);
        const response = await axios.get(`https://api.binance.com/api/v3/klines`, {
            params: { symbol, interval, limit }
        });

        const klines = response.data;
        if (!Array.isArray(klines) || klines.length === 0) throw new Error("Empty data from Binance");

        const csvRows = [
            "unix,date,symbol,open,high,low,close,Volume", // Header
            "0,0,0,0,0,0,0,0" // Dummy line 2 to match engine's start_idx = 2
        ];

        const chartData = [];

        klines.forEach(k => {
            const unix = parseInt(k[0]);
            const date = new Date(unix).toISOString().replace('T', ' ').substring(0, 19);
            const open = parseFloat(k[1]);
            const high = parseFloat(k[2]);
            const low = parseFloat(k[3]);
            const close = parseFloat(k[4]);
            const volume = parseFloat(k[5]);

            csvRows.push(`${unix},${date},${symbol},${open},${high},${low},${close},${volume}`);

            chartData.push({
                time: Math.floor(unix / 1000),
                open: open,
                high: high,
                low: low,
                close: close
            });
        });

        const csvPath = path.join(DATA_DIR, `${symbol}.csv`);
        fs.writeFileSync(csvPath, csvRows.join('\n'));

        console.log(`[Data Fetch] saved to ${csvPath} | bars: ${chartData.length}`);
        res.json({ success: true, chartData, csvPath });
    } catch (error) {
        console.error('Fetch error:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/run', (req, res) => {
    const { strategy, symbol, fast_window, slow_window, rsi_window, bollinger_window } = req.body;

    console.log(`[Run Request] Strategy: ${strategy} | Asset: ${symbol}`);

    if (MOCK_RESPONSE) {
        setTimeout(() => {
            res.json({ success: true, output: "[MOCK] Simulation Success." });
        }, 1000);
        return;
    }

    // IMPORTANT: WSL expects Unix-style relative paths
    const csvPath = `data/${symbol}.csv`;

    // Build arguments
    const args = ["--strategy", strategy, "--data", csvPath];
    if (fast_window) args.push("--fast-window", String(fast_window));
    if (slow_window) args.push("--slow-window", String(slow_window));
    if (rsi_window) args.push("--rsi-window", String(rsi_window));
    if (bollinger_window) args.push("--bb-window", String(bollinger_window));

    const cmd = `wsl mpirun -np ${MPI_NODES} --allow-run-as-root ./quantpdc_linux ${args.join(' ')}`;
    console.log(`[Execute] Running: ${cmd}`);

    // Execution via MPI Runner
    const subProcess = spawn('wsl', ['mpirun', '-np', String(MPI_NODES), '--allow-run-as-root', './quantpdc_linux', ...args], {
        cwd: path.join(__dirname, '..')
    });

    let stdout = '';
    let stderr = '';

    subProcess.stdout.on('data', (data) => {
        stdout += data.toString();
    });

    subProcess.stderr.on('data', (data) => {
        stderr += data.toString();
    });

    subProcess.on('close', (code) => {
        console.log(`[Execute] Process exited with code ${code}`);
        if (code === 0) {
            console.log(`[Execute] Success. Output length: ${stdout.length}`);
            res.json({ success: true, output: stdout });
        } else {
            console.error(`[Execute] Error: ${stderr || stdout}`);
            res.status(500).json({ success: false, error: stderr || stdout });
        }
    });
});

const PORT = 3001;
app.listen(PORT, () => {
    console.log(`QuantEngine Backend API listening on http://localhost:${PORT}`);
});
