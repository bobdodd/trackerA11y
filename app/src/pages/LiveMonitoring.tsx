import React from 'react';
import { Typography, Box, Alert } from '@mui/material';

interface LiveMonitoringProps {
  isTracking: boolean;
}

const LiveMonitoring: React.FC<LiveMonitoringProps> = ({ isTracking }) => {
  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Live Monitoring
      </Typography>
      
      {!isTracking ? (
        <Alert severity="info">
          Start recording to see real-time events
        </Alert>
      ) : (
        <Typography>
          Real-time event stream will be implemented here
        </Typography>
      )}
    </Box>
  );
};

export default LiveMonitoring;