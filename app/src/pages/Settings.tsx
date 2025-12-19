import React, { useState } from 'react';
import {
  Typography,
  Box,
  Paper,
  TextField,
  Button,
  Alert,
  Grid
} from '@mui/material';
import { useElectronAPI } from '../hooks/useElectronAPI';

interface SettingsProps {
  isConnected: boolean;
}

const Settings: React.FC<SettingsProps> = ({ isConnected }) => {
  const { electronAPI } = useElectronAPI();
  const [connectionString, setConnectionString] = useState('mongodb://localhost:27017');
  const [isConnecting, setIsConnecting] = useState(false);

  const handleConnect = async () => {
    setIsConnecting(true);
    try {
      await electronAPI?.database.connect(connectionString);
    } catch (error) {
      console.error('Connection failed:', error);
    } finally {
      setIsConnecting(false);
    }
  };

  const handleDisconnect = async () => {
    try {
      await electronAPI?.database.disconnect();
    } catch (error) {
      console.error('Disconnect failed:', error);
    }
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Settings
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Database Configuration
            </Typography>
            
            {isConnected && (
              <Alert severity="success" sx={{ mb: 2 }}>
                Successfully connected to MongoDB
              </Alert>
            )}

            <TextField
              fullWidth
              label="MongoDB Connection String"
              value={connectionString}
              onChange={(e) => setConnectionString(e.target.value)}
              disabled={isConnected}
              sx={{ mb: 2 }}
            />

            {!isConnected ? (
              <Button
                variant="contained"
                onClick={handleConnect}
                disabled={isConnecting || !connectionString.trim()}
              >
                Connect to Database
              </Button>
            ) : (
              <Button
                variant="outlined"
                onClick={handleDisconnect}
                color="error"
              >
                Disconnect
              </Button>
            )}
          </Paper>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Settings;