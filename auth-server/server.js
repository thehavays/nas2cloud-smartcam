const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.urlencoded({ extended: true }));

const clientIdEnv = process.env.GOOGLE_CLIENT_ID || '';
const clientSecretEnv = process.env.GOOGLE_CLIENT_SECRET || '';

let storedClientId = clientIdEnv;
let storedClientSecret = clientSecretEnv;
let storedLocalRetention = '7';
let storedRemoteRetention = '30';
const REDIRECT_URI = 'http://127.0.0.1:8080/callback';

app.get('/', (req, res) => {
    const rclonePath = path.join(__dirname, 'rclone', 'rclone.conf');
    let isConfigured = false;
    if (fs.existsSync(rclonePath)) {
        const content = fs.readFileSync(rclonePath, 'utf8');
        if (content.includes('[gdrive]')) isConfigured = true;
    }

    res.send(`
        <html>
        <head>
            <title>Nas2Cloud SmartCam - Setup</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 40px auto; padding: 20px; line-height: 1.6; color: #333; }
                input { width: 100%; padding: 10px; margin-bottom: 15px; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
                button { background: #4285f4; color: white; border: none; padding: 12px 20px; cursor: pointer; border-radius: 4px; font-size: 16px; width: 100%; font-weight: bold; }
                button:hover { background: #3367d6; }
                .success { background: #d4edda; color: #155724; padding: 15px; border-radius: 4px; margin-bottom: 20px; border: 1px solid #c3e6cb; }
                .card { background: #f8f9fa; padding: 20px; border-radius: 8px; border: 1px solid #e9ecef; }
            </style>
        </head>
        <body>
            <h2>Google Drive Authentication</h2>
            ${isConfigured ? '<div class="success">✅ Google Drive is already connected! You can close this page.</div>' : ''}
            
            <div class="card">
                <p>${clientIdEnv ? 'Your server is pre-configured with a Google Cloud Project. Just click below to securely connect your Google Drive.' : 'Enter your Google Cloud OAuth Client ID and Secret to securely connect your Google Drive.'}</p>
                <form action="/login" method="POST">
                    ${clientIdEnv ? '' : `
                    <label><b>Client ID:</b></label>
                    <input type="text" name="clientId" required placeholder="e.g. 123456789-abc.apps.googleusercontent.com">
                    
                    <label><b>Client Secret:</b></label>
                    <input type="password" name="clientSecret" required placeholder="e.g. GOCSPX-123456789">
                    `}
                    
                    <label><b>Local Retention (Days):</b></label>
                    <input type="number" name="localRetention" required value="7" min="1">
                    <small style="display:block;margin-top:-10px;margin-bottom:15px;color:#666;">How long to keep videos on your local PC before deleting.</small>

                    <label><b>Google Drive Retention (Days):</b></label>
                    <input type="number" name="remoteRetention" required value="30" min="1">
                    <small style="display:block;margin-top:-10px;margin-bottom:15px;color:#666;">How long to keep videos on Google Drive before deleting.</small>
                    
                    <button type="submit">Connect Google Drive</button>
                </form>
            </div>
            
            ${clientIdEnv ? '' : '<p><small><b>Need keys?</b> Go to <a href="https://console.cloud.google.com/" target="_blank">Google Cloud Console</a> &rarr; Create Project &rarr; <b>Enable "Google Drive API"</b> &rarr; Credentials &rarr; Create OAuth Client ID (Desktop App).</small></p>'}
        </body>
        </html>
    `);
});

app.post('/login', (req, res) => {
    storedClientId = clientIdEnv || req.body.clientId.trim();
    storedClientSecret = clientSecretEnv || req.body.clientSecret.trim();
    storedLocalRetention = req.body.localRetention || '7';
    storedRemoteRetention = req.body.remoteRetention || '30';

    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
        `client_id=${storedClientId}&` +
        `redirect_uri=${encodeURIComponent(REDIRECT_URI)}&` +
        `response_type=code&` +
        `scope=https://www.googleapis.com/auth/drive&` +
        `access_type=offline&` +
        `prompt=consent`;

    res.redirect(authUrl);
});

app.get('/callback', async (req, res) => {
    const code = req.query.code;
    if (!code) return res.send('Error: No authorization code provided.');
    if (!storedClientId || !storedClientSecret) return res.send('Error: Session lost. Please go back and try again.');

    try {
        const response = await axios.post('https://oauth2.googleapis.com/token', {
            code: code,
            client_id: storedClientId,
            client_secret: storedClientSecret,
            redirect_uri: REDIRECT_URI,
            grant_type: 'authorization_code'
        });

        const tokenData = response.data;
        const rcloneToken = JSON.stringify({
            access_token: tokenData.access_token,
            token_type: "Bearer",
            refresh_token: tokenData.refresh_token,
            expiry: new Date(Date.now() + tokenData.expires_in * 1000).toISOString()
        });

        const configContent = `[gdrive]
type = drive
scope = drive
client_id = ${storedClientId}
client_secret = ${storedClientSecret}
token = ${rcloneToken}
`;

        const rclonePath = path.join(__dirname, 'rclone', 'rclone.conf');
        const settingsPath = path.join(__dirname, 'rclone', 'settings.env');
        fs.mkdirSync(path.dirname(rclonePath), { recursive: true });
        fs.writeFileSync(rclonePath, configContent, 'utf8');
        fs.writeFileSync(settingsPath, `LOCAL_RETENTION_DAYS=${storedLocalRetention}\nREMOTE_RETENTION_DAYS=${storedRemoteRetention}\n`, 'utf8');

        res.send(`
            <html>
            <head>
                <style>
                    body { font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 20px; line-height: 1.6; color: #333; text-align: center; }
                    .success { background: #d4edda; color: #155724; padding: 20px; border-radius: 8px; border: 1px solid #c3e6cb; margin-bottom: 20px; }
                    .restart { background: #fff3cd; color: #856404; padding: 20px; border-radius: 8px; border: 1px solid #ffc107; text-align: left; }
                    .restart code { display: block; background: #212529; color: #f8f9fa; padding: 10px 15px; border-radius: 4px; margin-top: 10px; font-size: 14px; letter-spacing: 0.5px; }
                </style>
            </head>
            <body>
                <div class="success">
                    <h2>🎉 Success!</h2>
                    <p>Google Drive has been securely connected and your configuration has been saved.</p>
                </div>
                <div class="restart">
                    <strong>⚠️ Restart required to apply the new configuration.</strong>
                    <p>Run the following command on your host machine:</p>
                    <code>docker compose -f docker-compose-linux.yml restart</code>
                </div>
            </body>
            </html>
        `);

    } catch (err) {
        console.error(err.response ? err.response.data : err.message);
        res.send(`<h2>Error fetching tokens</h2><pre>${JSON.stringify(err.response ? err.response.data : err.message, null, 2)}</pre>`);
    }
});

app.listen(8080, '0.0.0.0', () => {
    console.log('Auth server listening on http://0.0.0.0:8080');
});
