// Watch Integration Service for Main Bitpoints App
// Handles sending tokens from phone to connected Wear OS watch

import { ref } from 'vue'
import { useLocalStorage } from '@vueuse/core'

export interface WatchConnection {
  id: string
  name: string
  endpoint: string
  lastSeen: number
}

export function useWatchIntegration() {
  const connectedWatches = useLocalStorage<WatchConnection[]>('bitpoints.connectedWatches', [])
  const isScanningForWatches = ref(false)
  
  /**
   * Parse QR code data to extract watch pairing info
   */
  function parseWatchQR(qrData: string): WatchConnection | null {
    try {
      if (qrData.startsWith('bitpoints://pair?data=')) {
        const jsonData = qrData.substring(19) // Remove 'bitpoints://pair?data='
        const data = JSON.parse(jsonData)
        return {
          id: data.id,
          name: data.name || 'My Watch',
          endpoint: data.endpoint,
          lastSeen: Date.now()
        }
      } else if (qrData.startsWith('https://bitpoints.me/receive/')) {
        const watchId = qrData.substring(30) // Remove 'https://bitpoints.me/receive/'
        return {
          id: watchId,
          name: 'Wear OS Watch',
          endpoint: qrData,
          lastSeen: Date.now()
        }
      }
      return null
    } catch (error) {
      console.error('Failed to parse watch QR code:', error)
      return null
    }
  }
  
  /**
   * Add or update a connected watch
   */
  function addWatch(watch: WatchConnection) {
    const existingIndex = connectedWatches.value.findIndex(w => w.id === watch.id)
    if (existingIndex >= 0) {
      connectedWatches.value[existingIndex] = watch
    } else {
      connectedWatches.value.push(watch)
    }
    console.log('Watch added/updated:', watch.name)
  }
  
  /**
   * Remove a watch connection
   */
  function removeWatch(watchId: string) {
    const index = connectedWatches.value.findIndex(w => w.id === watchId)
    if (index >= 0) {
      connectedWatches.value.splice(index, 1)
      console.log('Watch removed:', watchId)
    }
  }
  
  /**
   * Send token to a specific watch
   */
  async function sendTokenToWatch(watchId: string, tokenString: string, memo?: string): Promise<boolean> {
    const watch = connectedWatches.value.find(w => w.id === watchId)
    if (!watch) {
      console.error('Watch not found:', watchId)
      return false
    }
    
    try {
      const response = await fetch(watch.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token: tokenString,
          sender: 'bitpoints_phone',
          timestamp: Date.now(),
          memo: memo
        })
      })
      
      if (response.ok) {
        console.log('Token sent to watch successfully')
        return true
      } else {
        console.error('Failed to send token to watch:', response.statusText)
        return false
      }
    } catch (error) {
      console.error('Error sending token to watch:', error)
      return false
    }
  }
  
  /**
   * Send token to all connected watches
   */
  async function sendTokenToAllWatches(tokenString: string, memo?: string): Promise<{ success: number, failed: number }> {
    let success = 0
    let failed = 0
    
    for (const watch of connectedWatches.value) {
      const result = await sendTokenToWatch(watch.id, tokenString, memo)
      if (result) {
        success++
      } else {
        failed++
      }
    }
    
    return { success, failed }
  }
  
  /**
   * Check if any watches are connected
   */
  function hasConnectedWatches(): boolean {
    return connectedWatches.value.length > 0
  }
  
  /**
   * Get watch connection status
   */
  function getWatchStatus(watchId: string): 'connected' | 'disconnected' | 'unknown' {
    const watch = connectedWatches.value.find(w => w.id === watchId)
    if (!watch) return 'unknown'
    
    // Consider watch connected if seen within last 5 minutes
    const fiveMinutesAgo = Date.now() - (5 * 60 * 1000)
    return watch.lastSeen > fiveMinutesAgo ? 'connected' : 'disconnected'
  }
  
  return {
    connectedWatches,
    isScanningForWatches,
    parseWatchQR,
    addWatch,
    removeWatch,
    sendTokenToWatch,
    sendTokenToAllWatches,
    hasConnectedWatches,
    getWatchStatus
  }
}

