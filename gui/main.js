document.addEventListener('DOMContentLoaded', () => {
    const strategySelect = document.getElementById('strategy');
    const runBtn = document.getElementById('runBtn');
    const resultsBody = document.getElementById('resultsBody');
    const sysStatus = document.getElementById('sysStatus');
    const perfValue = document.getElementById('perfValue');

    // Strategy parameters switching logic
    strategySelect.addEventListener('change', (e) => {
        const strategy = e.target.value;
        const allParams = document.querySelectorAll('.strategy-params');
        allParams.forEach(p => p.style.display = 'none');
        
        const activeParams = document.getElementById(`params-${strategy}`);
        if (activeParams) activeParams.style.display = 'block';
    });

    // Run Engine Logic
    runBtn.addEventListener('click', async () => {
        const strategy = strategySelect.value;
        const payload = { strategy };

        // Collect parameters based on strategy
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

        // Update UI state
        runBtn.disabled = true;
        runBtn.textContent = 'RUNNING...';
        sysStatus.textContent = 'EXECUTING';
        resultsBody.innerHTML = '<tr><td colspan="5" style="text-align: center; color: var(--accent-color); padding: 40px;">CONNECTING TO CLUSTER...</td></tr>';

        try {
            const response = await fetch('http://localhost:3001/api/run', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const data = await response.json();
            
            if (data.success) {
                parseAndDisplayOutput(data.output);
                sysStatus.textContent = 'SUCCESS';
            } else {
                throw new Error(data.error || 'Execution failed');
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

    // Simple parser for the CLI dashboard output
    function parseAndDisplayOutput(output) {
        const lines = output.split('\n');
        let html = '';
        let perfFound = false;

        // Simple regex to find the throughput
        const perfMatch = output.match(/throughput: ([\d.]+) bars\/sec/);
        if (perfMatch) {
            perfValue.textContent = parseFloat(perfMatch[1]).toLocaleString();
        }

        // Extracting table rows
        const dataRows = lines.filter(line => line.includes('BUY') || line.includes('SELL'));

        if (dataRows.length === 0) {
            html = '<tr><td colspan="5" style="text-align: center; padding: 40px;">NO SIGNALS GENERATED</td></tr>';
        } else {
            dataRows.forEach(row => {
                // Remove ANSI colors and extra spaces
                const cleanRow = row.replace(/\u001b\[[0-9;]*m/g, '').trim();
                const parts = cleanRow.split(/\s+/);
                
                // TIMESTAMP (index 0,1) SIGNAL (2) ENTRY (3) FWD (4) VAL (5) OUTCOME (6)
                // Note: This matches the C++ dashboard formatting specifically
                const timestamp = `${parts[0]} ${parts[1]}`;
                const signal = parts[2];
                const entry = parts[3];
                const forward = parts[4];
                const outcome = parts[members - 1]; // Outcome is usually the last word
                
                const sigClass = signal === 'BUY' ? 'signal-buy' : 'signal-sell';
                const outcomeClass = outcome === 'PROFIT' ? 'outcome-profit' : 'outcome-loss';

                html += `
                    <tr>
                        <td>${timestamp}</td>
                        <td class="${sigClass}">${signal}</td>
                        <td>${entry}</td>
                        <td>${forward}</td>
                        <td><span class="${outcomeClass}">${outcome}</span></td>
                    </tr>
                `;
            });
        }

        resultsBody.innerHTML = html;
    }
});
