/**
 * Navigation Sidebar Component
 */

import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  Drawer,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  ListItemButton,
  Toolbar,
  Divider,
  Box,
  Chip
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  Visibility as MonitorIcon,
  History as SessionsIcon,
  Analytics as AnalyticsIcon,
  Settings as SettingsIcon
} from '@mui/icons-material';

interface NavigationSidebarProps {
  isTracking: boolean;
  isConnected: boolean;
  currentSessionId: string | null;
}

const NavigationSidebar: React.FC<NavigationSidebarProps> = ({
  isTracking,
  isConnected,
  currentSessionId
}) => {
  const location = useLocation();
  const navigate = useNavigate();

  const menuItems = [
    { path: '/dashboard', label: 'Dashboard', icon: <DashboardIcon /> },
    { path: '/monitor', label: 'Live Monitor', icon: <MonitorIcon /> },
    { path: '/sessions', label: 'Sessions', icon: <SessionsIcon /> },
    { path: '/analytics', label: 'Analytics', icon: <AnalyticsIcon /> },
  ];

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: 240,
        flexShrink: 0,
        '& .MuiDrawer-paper': {
          width: 240,
          boxSizing: 'border-box',
        },
      }}
    >
      <Toolbar />
      
      <Box sx={{ overflow: 'auto', flex: 1 }}>
        <List>
          {menuItems.map((item) => (
            <ListItemButton
              key={item.path}
              selected={location.pathname === item.path}
              onClick={() => navigate(item.path)}
            >
              <ListItemIcon>{item.icon}</ListItemIcon>
              <ListItemText primary={item.label} />
            </ListItemButton>
          ))}
        </List>
        
        <Divider />
        
        <List>
          <ListItemButton
            selected={location.pathname === '/settings'}
            onClick={() => navigate('/settings')}
          >
            <ListItemIcon><SettingsIcon /></ListItemIcon>
            <ListItemText primary="Settings" />
          </ListItemButton>
        </List>
      </Box>

      {/* Status Footer */}
      <Box sx={{ p: 2, borderTop: 1, borderColor: 'divider' }}>
        {isTracking && (
          <Chip
            label={`Recording`}
            color="success"
            size="small"
            sx={{ mb: 1, display: 'block' }}
          />
        )}
        {isConnected && (
          <Chip
            label="DB Connected"
            color="primary"
            size="small"
            variant="outlined"
          />
        )}
      </Box>
    </Drawer>
  );
};

export default NavigationSidebar;