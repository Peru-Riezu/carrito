const { Client } = require('pg');
const fs = require('fs').promises;

async function migrate_offers(ip, username, password, dbName)
{
	let client_carrito;

	try
	{
        client_carrito = new Client
		(
			{
	            host: ip,
	            user: username,
	            password: password,
	            database: dbName // connect to "carrito" now that it exists
	        }
		);

        await client_carrito.connect();
        
        // Read the SQL file that drops and recreates the database
		await client_carrito.query
		(
			`SELECT create_offer
			(
				'migrador', 
				'\\x0000000000000000000000000000000000000000000000000000000000000000', 
				'011112', 
				'Offer Title', 
				0, 
				'Offer Location', 
				'Some observations', 
				'Some notes'
			);`
		);

		await client_carrito.query
		(
			`SELECT delete_offer
			(
				'migrador', 
				'\\x0000000000000000000000000000000000000000000000000000000000000000', 
				'011114'
			);`
		)
	}
	catch (err)
	{
        console.error('Error:', err.message);
	}
	finally
	{
        await client_carrito.end();
	}
}

async function create_database(ip, username, password, dbName) {
    let client_carrito;

    try {
        client_carrito = new Client({
            host: ip,
            user: username,
            password: password,
            database: 'postgres' // Connect to postgres first to manage databases
        });

        await client_carrito.connect();

        // Drop and recreate the database
        await client_carrito.query('DROP DATABASE IF EXISTS carrito');
        await client_carrito.query('DROP USER IF EXISTS gateway_role');
        await client_carrito.query('CREATE DATABASE carrito');
        await client_carrito.end();

        // Reconnect to the new database
        client_carrito = new Client({
            host: ip,
            user: username,
            password: password,
            database: dbName
        });

        await client_carrito.connect();

        const createTables = await fs.readFile('create_tables.sql', 'utf8');

        try {
            // Directly execute the full SQL string
            await client_carrito.query(createTables);
            console.log('Database recreated and tables created successfully!');
        } catch (err) {
            console.error('Error executing SQL file:', err.message);
            throw err;
        }
    } catch (err) {
        console.error('Error:', err.message);
    } finally {
        await client_carrito.end();
    }
}

async function main()
{
	await create_database('127.0.0.1', 'postgres', 'vD6jxIe8bgz2dDyAo4VH9G4t6u7qha', 'carrito');
	await migrate_offers('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito')
}

main()
