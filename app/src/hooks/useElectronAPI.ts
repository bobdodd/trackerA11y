/**
 * React hook for accessing Electron API
 */

import { useEffect, useState } from 'react';

declare global {
  interface Window {
    electronAPI: any;
  }
}

export const useElectronAPI = () => {
  const [electronAPI, setElectronAPI] = useState<any>(null);
  const [isElectronAvailable, setIsElectronAvailable] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined' && window.electronAPI) {
      setElectronAPI(window.electronAPI);
      setIsElectronAvailable(true);
    } else {
      console.warn('Electron API not available');
    }
  }, []);

  return { electronAPI, isElectronAvailable };
};