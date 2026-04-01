const express = require('express');
const cors = require('cors');
const { spawn } = require('child_process');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

// Serve static frontend files from the /gui directory
app.use(express.static(path.join(__dirname, '..', 'gui')));

// Set to false to enable real execution in WSL2
const MOCK_RESPONSE = false;

app.post('/api/run', (req, res) => {
    const { strategy, fast_window, slow_window, rsi_window, bollinger_window } = req.body;
    
    console.log(`[Run Request] Strategy: ${strategy}`);

    if (MOCK_RESPONSE) {
        // Send a mock successful response to the dashboard
        setTimeout(() => {
            const mockData = `
 \x1b[1;33m[NODE-0 DASHBOARD: ${strategy}]\x1b[0m
 -----------------------------------------------------------------------------------------------
 TIMESTAMP           SIGNAL    ENTRY          FWD-50         VALIDATE                OUTCOME
 -----------------------------------------------------------------------------------------------
 2023-01-15 08:00    \x1b[1;32mBUY \x1b[0m      $21450.50      $23100.00      \x1b[1;32mCORRECT\x1b[0m                 PROFIT
 2023-02-10 12:00    \x1b[1;31mSELL\x1b[0m      $24000.20      $22500.00      \x1b[1;32mCORRECT\x1b[0m                 PROFIT
 -----------------------------------------------------------------------------------------------
 [MPI-0] success: 2 signals | win rate: 100.0%
            `;
            res.json({ success: true, output: mockData });
        }, 1500);
        return;
    }

    // Example of constructing the arguments for the executable
    const args = ["--strategy", strategy];
    if (fast_window) args.push("--fast-window", String(fast_window));
    if (slow_window) args.push("--slow-window", String(slow_window));
    if (rsi_window) args.push("--rsi-window", String(rsi_window));
    if (bollinger_window) args.push("--bb-window", String(bollinger_window));

    // Execution in WSL2
    // We launch via 'wsl' and run the linux binary
    const process = spawn('wsl', ['./quantpdc_linux', ...args], {
        cwd: path.join(__dirname, '..')
    });

    let stdout = '';
    let stderr = '';

    process.stdout.on('data', (data) => {
        stdout += data.toString();
    });

    process.stderr.on('data', (data) => {
        stderr += data.toString();
    });

    process.on('close', (code) => {
        if (code === 0) {
            res.json({ success: true, output: stdout });
        } else {
            res.status(500).json({ success: false, error: stderr || stdout });
        }
    });
});

const PORT = 3001;
app.listen(PORT, () => {
    console.log(`QuantEngine Backend API listening on http://localhost:${PORT}`);
});
