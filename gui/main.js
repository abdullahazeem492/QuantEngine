document.addEventListener('DOMContentLoaded', async () => {
    console.log("QuantEngine UI initializing...");
    if (typeof LightweightCharts === 'undefined') {
        console.error("CRITICAL: LightweightCharts library NOT found. Check your internet connection or the CDN in index.html.");
        document.getElementById('chart').innerHTML = '<div style="color: var(--danger); padding: 40px; text-align: center;">CHARTING LIBRARY FAILED TO LOAD.<br>Check your internet connection.</div>';
        return;
    }

    const assetSelect = document.getElementById('asset');
    const strategySelect = document.getElementById('strategy');
    const runBtn = document.getElementById('runBtn');
    const resultsBody = document.getElementById('resultsBody');
    const sysStatus = document.getElementById('sysStatus');
    const perfValue = document.getElementById('perfValue');

    // --- Asset Loading (Moved to top) ---
    async function loadAssets() {
        try {
            console.log("Fetching assets...");
            const response = await fetch('/api/assets');
            if (!response.ok) throw new Error("Assets API failed");
            const assets = await response.json();
            assetSelect.innerHTML = assets.map(a => `<option value="${a.symbol}">${a.name} (${a.symbol})</option>`).join('');
        } catch (err) {
            console.error('Failed to load assets:', err);
            sysStatus.textContent = 'API ERROR';
            assetSelect.innerHTML = '<option value="BTCUSDT">Connection Error (check console)</option>';
        }
    }
    await loadAssets();

    // --- Chart Initialization ---
    let candlestickSeries;
    let chart;
    const chartContainer = document.getElementById('chart');

    try {
        chart = LightweightCharts.createChart(chartContainer, {
            layout: {
                background: { type: 'solid', color: 'transparent' },
                textColor: '#a0a0a0',
            },
            grid: {
                vertLines: { color: 'rgba(255, 255, 255, 0.05)' },
                horzLines: { color: 'rgba(255, 255, 255, 0.05)' },
            },
            crosshair: { mode: LightweightCharts.CrosshairMode.Normal },
            rightPriceScale: { borderColor: 'rgba(255, 255, 255, 0.1)' },
            timeScale: { borderColor: 'rgba(255, 255, 255, 0.1)', timeVisible: true },
        });

        if (!chart || typeof chart.addCandlestickSeries !== 'function') {
            throw new Error("createChart succeeded but addCandlestickSeries is missing. Your browser might be cacheing an incompatible version.");
        }

        candlestickSeries = chart.addCandlestickSeries({
            upColor: '#00ffcc',
            downColor: '#ff4d4d',
            borderVisible: false,
            wickUpColor: '#00ffcc',
            wickDownColor: '#ff4d4d',
        });

        // Handle window resize
        window.addEventListener('resize', () => {
            chart.applyOptions({ width: chartContainer.clientWidth });
        });
    } catch (chartErr) {
        console.error("Failed to initialize chart:", chartErr);
        chartContainer.innerHTML = `<div style="color: var(--danger); padding: 40px; text-align: center;">CHART CONFIG ERROR: ${chartErr.message}<br>Check console for details.</div>`;
    }

    // --- Asset Loading ---
    // (Moved to top of initialization)

    // Strategy parameters switching logic
    strategySelect.addEventListener('change', (e) => {
        const strategy = e.target.value;
        document.querySelectorAll('.strategy-params').forEach(p => p.style.display = 'none');
        const activeParams = document.getElementById(`params-${strategy}`);
        if (activeParams) activeParams.style.display = 'block';
    });

    // --- Run Engine Logic ---
    runBtn.addEventListener('click', async () => {
        const strategy = strategySelect.value;
        const symbol = assetSelect.value;
        
        // Update UI state
        runBtn.disabled = true;
        runBtn.textContent = 'EXECUTING...';
        sysStatus.textContent = 'FETCHING DATA';
        resultsBody.innerHTML = '<tr><td colspan="5" style="text-align: center; color: var(--accent-color); padding: 40px;">CONNECTING TO CLUSTER...</td></tr>';

        try {
            // STEP 1: Fetch dynamic data and update chart
            const dataResponse = await fetch(`/api/fetch-data/${symbol}`);
            const dataJson = await dataResponse.json();
            
            if (!dataJson.success) throw new Error(dataJson.error);
            
            console.log(`Received ${dataJson.chartData.length} bars of chart data.`);
            
            if (candlestickSeries && dataJson.chartData.length > 0) {
                candlestickSeries.setData(dataJson.chartData);
                if (chart) chart.timeScale().fitContent(); 
            } else {
                console.warn("No chart data received or series not ready.");
            }

            // STEP 2: Run Simulation
            sysStatus.textContent = 'RUNNING PDC ENGINE';
            const payload = { strategy, symbol };

            // Collect strategy-specific parameters
            if (strategy === 'golden_cross') {
                payload.fast_window = parseInt(document.getElementById('fast_window').value);
                payload.slow_window = parseInt(document.getElementById('slow_window').value);
            } else if (strategy === 'rsi') {
                payload.rsi_window = parseInt(document.getElementById('rsi_window').value);
                payload.rsi_overbought = parseFloat(document.getElementById('rsi_overbought').value);
                payload.rsi_oversold = parseFloat(document.getElementById('rsi_oversold').value);
            } else if (strategy === 'mean_reversion') {
                payload.bollinger_window = parseInt(document.getElementById('bb_window').value);
                payload.bollinger_stddev = parseFloat(document.getElementById('bb_stddev').value);
            }

            const simResponse = await fetch('/api/run', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const simData = await simResponse.json();
            
            console.log("Raw Simulation Output:", simData.output); // CRITICAL FOR DEBUGGING

            if (simData.success) {
                const signals = parseAndDisplayOutput(simData.output);
                updateChartMarkers(signals);
                sysStatus.textContent = 'SUCCESS';
            } else {
                throw new Error(simData.error || 'Execution failed');
            }
        } catch (error) {
            console.error('Simulation error:', error);
            resultsBody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--danger); padding: 40px;">ERROR: ${error.message}</td></tr>`;
            sysStatus.textContent = 'ERROR';
        } finally {
            runBtn.disabled = false;
            runBtn.textContent = 'RUN ENGINE';
        }
    });

    function parseAndDisplayOutput(output) {
        if (!output) return [];
        const lines = output.split('\n');
        let html = '';
        const signals = [];

        // Parse throughput
        const perfMatch = output.match(/throughput: ([\d.]+) bars\/sec/);
        if (perfMatch) {
            perfValue.textContent = parseFloat(perfMatch[1]).toLocaleString();
        }

        // Parse signals from table
        const dataRows = lines.filter(line => line.includes('BUY') || line.includes('SELL'));

        if (dataRows.length === 0) {
            html = '<tr><td colspan="5" style="text-align: center; padding: 40px;">NO SIGNALS GENERATED</td></tr>';
        } else {
            console.log(`Parsed ${dataRows.length} signal rows.`);
            dataRows.forEach(row => {
                const parts = row.trim().split(/\s+/);
                
                // C++ Format: TIMESTAMP (parts 0,1) SIGNAL (2) ENTRY (3)
                const timestampStr = `${parts[0]} ${parts[1]}`;
                const signalType = parts[2];
                const entry = parts[3] ? parts[3].replace('$', '') : '0';
                const forward = parts[4] ? parts[4].replace('$', '') : '0';
                const outcome = parts[parts.length - 1];
                
                signals.push({
                    time: new Date(timestampStr).getTime() / 1000,
                    type: signalType,
                    price: parseFloat(entry)
                });

                const sigClass = signalType === 'BUY' ? 'signal-buy' : 'signal-sell';
                const outcomeClass = outcome === 'PROFIT' ? 'outcome-profit' : 'outcome-loss';

                html += `
                    <tr>
                        <td>${timestampStr}</td>
                        <td class="${sigClass}">${signalType}</td>
                        <td>${entry}</td>
                        <td>${forward}</td>
                        <td><span class="${outcomeClass}">${outcome}</span></td>
                    </tr>
                `;
            });
        }

        resultsBody.innerHTML = html;
        return signals;
    }

    function updateChartMarkers(signals) {
        if (!candlestickSeries) return;
        const markers = signals.map(sig => ({
            time: sig.time,
            position: sig.type === 'BUY' ? 'belowBar' : 'aboveBar',
            color: sig.type === 'BUY' ? '#00ffcc' : '#ff4d4d',
            shape: sig.type === 'BUY' ? 'arrowUp' : 'arrowDown',
            text: sig.type
        }));
        candlestickSeries.setMarkers(markers);
    }
});
