// ================================================================
// Smart Zero Waste City - Service Worker
// ================================================================

const CACHE_NAME = 'zero-waste-v3';
const urlsToCache = [
    '/',
    '/index.html',
    '/manifest.json',
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css',
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
];

// ==================== INSTALL ====================
self.addEventListener('install', event => {
    console.log('📦 Service Worker: Installing...');
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                console.log('📦 Caching assets...');
                return cache.addAll(urlsToCache);
            })
            .then(() => {
                console.log('✅ Service Worker: Installed!');
                return self.skipWaiting();
            })
            .catch(error => {
                console.error('❌ Service Worker: Install failed:', error);
            })
    );
});

// ==================== ACTIVATE ====================
self.addEventListener('activate', event => {
    console.log('🔄 Service Worker: Activating...');
    event.waitUntil(
        caches.keys().then(cacheNames => {
            return Promise.all(
                cacheNames.map(name => {
                    if (name !== CACHE_NAME) {
                        console.log('🗑️ Deleting old cache:', name);
                        return caches.delete(name);
                    }
                })
            );
        }).then(() => {
            console.log('✅ Service Worker: Activated!');
            return self.clients.claim();
        })
    );
});

// ==================== FETCH ====================
self.addEventListener('fetch', event => {
    event.respondWith(
        fetch(event.request)
            .then(response => {
                // Cache successful responses
                if (response && response.status === 200) {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then(cache => {
                        try {
                            cache.put(event.request, clone);
                        } catch (e) {
                            // Ignore caching errors for non-cacheable resources
                        }
                    });
                }
                return response;
            })
            .catch(() => {
                // Fallback to cache
                return caches.match(event.request)
                    .then(cachedResponse => {
                        if (cachedResponse) {
                            return cachedResponse;
                        }
                        // If not in cache, return offline page
                        return caches.match('/index.html');
                    });
            })
    );
});

// ==================== BACKGROUND SYNC ====================
self.addEventListener('sync', event => {
    if (event.tag === 'sync-requests') {
        console.log('🔄 Syncing pending requests...');
        event.waitUntil(syncPendingRequests());
    }
});

async function syncPendingRequests() {
    try {
        // Open IndexedDB
        const db = await openDB();
        const pendingRequests = await getPendingRequests(db);
        
        for (const request of pendingRequests) {
            try {
                const response = await fetch(request.url, {
                    method: request.method,
                    headers: request.headers,
                    body: request.body
                });
                
                if (response.ok) {
                    await deletePendingRequest(db, request.id);
                    console.log('✅ Synced request:', request.id);
                }
            } catch (error) {
                console.error('❌ Sync failed for request:', request.id, error);
            }
        }
    } catch (error) {
        console.error('❌ Sync error:', error);
    }
}

// ==================== PUSH NOTIFICATIONS ====================
self.addEventListener('push', event => {
    const data = event.data.json();
    const options = {
        body: data.body || 'New notification',
        icon: '/assets/icons/icon-192x192.png',
        badge: '/assets/icons/icon-72x72.png',
        vibrate: [200, 100, 200],
        data: {
            url: data.url || '/',
            timestamp: Date.now()
        },
        actions: [
            { action: 'view', title: 'View' },
            { action: 'dismiss', title: 'Dismiss' }
        ]
    };
    
    event.waitUntil(
        self.registration.showNotification(data.title || 'Smart Zero Waste City', options)
    );
});

// ==================== NOTIFICATION CLICK ====================
self.addEventListener('notificationclick', event => {
    event.notification.close();
    
    if (event.action === 'dismiss') {
        return;
    }
    
    const url = event.notification.data?.url || '/';
    event.waitUntil(
        clients.openWindow(url)
    );
});

// ==================== INDEXEDDB HELPERS ====================
function openDB() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open('zero-waste-sync', 1);
        
        request.onupgradeneeded = (event) => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains('pending')) {
                const store = db.createObjectStore('pending', { keyPath: 'id', autoIncrement: true });
                store.createIndex('url', 'url', { unique: false });
                store.createIndex('timestamp', 'timestamp', { unique: false });
            }
        };
        
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
    });
}

function getPendingRequests(db) {
    return new Promise((resolve, reject) => {
        const transaction = db.transaction('pending', 'readonly');
        const store = transaction.objectStore('pending');
        const request = store.getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
    });
}

function deletePendingRequest(db, id) {
    return new Promise((resolve, reject) => {
        const transaction = db.transaction('pending', 'readwrite');
        const store = transaction.objectStore('pending');
        const request = store.delete(id);
        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
    });
}

// ==================== OFFLINE REQUEST QUEUE ====================
self.addEventListener('message', event => {
    if (event.data && event.data.type === 'QUEUE_REQUEST') {
        const requestData = event.data.payload;
        queueRequest(requestData);
    }
});

async function queueRequest(requestData) {
    try {
        const db = await openDB();
        const transaction = db.transaction('pending', 'readwrite');
        const store = transaction.objectStore('pending');
        store.add({
            url: requestData.url,
            method: requestData.method || 'POST',
            headers: requestData.headers || {},
            body: requestData.body || null,
            timestamp: Date.now()
        });
        await transaction.complete;
        console.log('📝 Request queued for sync');
    } catch (error) {
        console.error('❌ Failed to queue request:', error);
    }
}