const { app, BrowserWindow, Menu, ipcMain, shell, globalShortcut} = require('electron');
const path = require('node:path');
const { Client } = require('pg');

let win;

const createWindow = () =>
{
	win = new BrowserWindow
	(
		{
			width: 800,
			height: 600,
			webPreferences:
			{
				preload: path.join(__dirname, 'preload.js'), // Make sure the preload script path is correct
				contextIsolation: true,  // Important for security
				enableRemoteModule: false, // Disable remote module for security
				nodeIntegration: false, // Disable node integration
	    	}
  		}
	);
	const contextMenu = Menu.buildFromTemplate
	(
		[
			{ label: 'Copy', role: 'copy' },
			{ label: 'Paste', role: 'paste' },
			{ type: 'separator' },
			{
				label: 'Inspect',
				click: () => {win.webContents.openDevTools();}
		    }
		]
	);

	win.webContents.on
	(
		'context-menu',
		(_, params) =>
		{
			contextMenu.popup
			(
				{
					window: win,
					x: params.x,
					y: params.y
				}
			);
		}
	);
	win.loadFile('index.html');
};


app.whenReady().then
(
	() =>
    {
        globalShortcut.register
    	(
    		'CommandOrControl+=',
    		() =>
    		{
    	        const focusedWindow = BrowserWindow.getFocusedWindow();
    	        if (focusedWindow)
    			{
    	            focusedWindow.webContents.setZoomLevel(focusedWindow.webContents.getZoomLevel() + 1);
    	        }
    	    }
    	);
        globalShortcut.register
    	(
    		'CommandOrControl+-',
    		() =>
    		{
    			const focusedWindow = BrowserWindow.getFocusedWindow();
    			if (focusedWindow)
    			{
                	focusedWindow.webContents.setZoomLevel(focusedWindow.webContents.getZoomLevel() - 1);
            	}
        	}
    	);
        globalShortcut.register
    	(
    		'CommandOrControl+0',
    		() =>
    		{
    	        const focusedWindow = BrowserWindow.getFocusedWindow();
    	        if (focusedWindow)
    			{
            		focusedWindow.webContents.setZoomLevel(0);
            	}
        	}
    	);
    }
);

app.on('will-quit', () => {globalShortcut.unregisterAll();});

Menu.setApplicationMenu(null);

async function get_proyect_and_offer_codes()
{
	const client = new Client
	(
		{
			user: 'carrito',
			host: 'localhost',
			database: 'carrito',
			password: 'aa',
			port: 5432
		}
	);

	try
	{
		await client.connect();
		const res = await client.query('SELECT * FROM doc_emitida_recivida.todos_los_codigos_formato_antiguo ORDER BY TRIM(codigo_trabajo) ASC;');
		await client.end();
 		return (res.rows);
 	}
	catch (error)
	{
		win.webContents.send('log', `Database Error: ${error.message}`);
		if (client) 
		{
			try {await client.end();} catch (endError){}
		}
		return ("Error de base de datos, contacte con el informático de turno, por favor.");
	}
}

app.whenReady().then(() => {createWindow();});
app.on('window-all-closed', () => {app.quit();});
ipcMain.handle('get-codes', async () => {const result = await get_proyect_and_offer_codes(); return (result);});
ipcMain.on('open-file-explorer', (_, path) => {shell.openPath(path);});