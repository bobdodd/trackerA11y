import React from 'react';
import ReactDOM from 'react-dom/client';
import { Typography, Box, AppBar, Toolbar, ThemeProvider, createTheme, CssBaseline } from '@mui/material';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#2196f3',
    },
  },
});

const TrackerApp: React.FC = () => {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Box>
        <AppBar position="static">
          <Toolbar>
            <Typography variant="h6">TrackerA11y</Typography>
          </Toolbar>
        </AppBar>
        <Box sx={{ p: 3 }}>
          <Typography variant="h4" gutterBottom>
            Welcome to TrackerA11y
          </Typography>
          <Typography>
            Desktop accessibility testing platform is loading...
          </Typography>
        </Box>
      </Box>
    </ThemeProvider>
  );
};

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <TrackerApp />
  </React.StrictMode>
);