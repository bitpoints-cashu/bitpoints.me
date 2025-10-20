/**
 * SafeAreaManager
 * 
 * JavaScript interface to handle safe area insets
 * This ensures proper layout on devices with notches/Dynamic Island
 */
class SafeAreaManager {
    constructor() {
        this.plugin = null;
        this.init();
    }
    
    async init() {
        // Wait for Capacitor to be ready
        if (window.Capacitor && window.Capacitor.Plugins) {
            this.plugin = window.Capacitor.Plugins.SafeAreaPlugin;
            await this.updateSafeAreaCSS();
        } else {
            // Fallback for web
            this.updateSafeAreaCSSFallback();
        }
    }
    
    async updateSafeAreaCSS() {
        if (this.plugin) {
            try {
                await this.plugin.updateSafeAreaCSS();
                console.log('Safe area CSS updated successfully');
            } catch (error) {
                console.error('Failed to update safe area CSS:', error);
                this.updateSafeAreaCSSFallback();
            }
        }
    }
    
    updateSafeAreaCSSFallback() {
        // Fallback CSS for web/development
        const css = `
            :root {
                --safe-area-inset-top: 0px;
                --safe-area-inset-bottom: 0px;
                --safe-area-inset-left: 0px;
                --safe-area-inset-right: 0px;
            }
            
            body {
                padding-top: env(safe-area-inset-top, 0px);
                padding-bottom: env(safe-area-inset-bottom, 0px);
                padding-left: env(safe-area-inset-left, 0px);
                padding-right: env(safe-area-inset-right, 0px);
            }
            
            .q-drawer, .q-header {
                margin-top: env(safe-area-inset-top, 0px);
            }
            
            /* Ensure content doesn't overlap with status bar */
            .q-page {
                padding-top: env(safe-area-inset-top, 0px);
            }
            
            /* Fix for logo being blocked by front camera */
            .q-toolbar, .q-header {
                padding-top: max(env(safe-area-inset-top, 0px), 20px);
            }
        `;
        
        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);
        
        console.log('Safe area CSS fallback applied');
    }
    
    async getSafeAreaInsets() {
        if (this.plugin) {
            try {
                const result = await this.plugin.getSafeAreaInsets();
                return result;
            } catch (error) {
                console.error('Failed to get safe area insets:', error);
                return { top: 0, bottom: 0, left: 0, right: 0 };
            }
        }
        return { top: 0, bottom: 0, left: 0, right: 0 };
    }
}

// Initialize safe area manager when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.safeAreaManager = new SafeAreaManager();
});

// Also initialize when Capacitor is ready
document.addEventListener('deviceready', () => {
    if (window.safeAreaManager) {
        window.safeAreaManager.init();
    }
});
