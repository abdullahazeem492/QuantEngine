const express = require('express');
const cors = require('cors');
const { spawn } = require('child_process');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

// Set to true to mock response (useful while WSL/MPI setup is pending)
const MOCK_RESPONSE = true;

app.post('/api/run', (req, res) => {
    const { strategy, fast_window, slow_window, rsi_window, bollinger_window } = req.body;
    
    console.log(`[Run Request] Strategy: ${strategy}`);

    if (MOCK_RESPONSE) {
        // Send a mock successful response to the dashboard
        setTimeout(() => {
            const mockData = `
 \033[1;33m[NODE-0 DASHBOARD: ${strategy}]\033[0m
 -----------------------------------------------------------------------------------------------
 TIMESTAMP           SIGNAL    ENTRY          FWD-50         VALIDATE                OUTCOME
 -----------------------------------------------------------------------------------------------
 2023-01-15 08:00    \033[1;32mBUY \033[0m      $21450.50      $23100.00      \033[1;32mCORRECT\033[0m                 PROFIT
 2023-02-10 12:00    \033[1;31mSELL\033[0m      $24000.20      $22500.00      \033[1;32mCORRECT\033[0m                 PROFIT
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

    // The executable path (assuming build directory)
    const executablePath = path.join(__dirname, '..', 'build', 'Release', 'quantpdc.exe');

    // Run without mpiexec by default for local dev
    const process = spawn(executablePath, args);

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
