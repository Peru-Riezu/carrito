const { Client } = require('pg');
const fs = require('fs').promises;
const XLSX = require('xlsx');

function mapMethodOfDelivery(methodNumber)
{
    switch (methodNumber)
	{
        case 1:
            return 'email';
        case 2:
            return 'cd';
        case 3:
            return 'messenger';
        case 4:
            return 'onhand';
        case 5:
            return 'fax';
        case 6:
            return 'ftp';
        default:
            return 'other';
    }
}

async function migrate_received_docs(ip, username, password, dbName)
{
    let client_carrito;

    try
	{
        client_carrito = new Client(
										{
								            host: ip,
								            user: username,
								            password: password,
								            database: dbName
										}
									);

        await client_carrito.connect();

        const workbook = XLSX.readFile('docRecibidaCarrito_cleaned.XLS');
        const sheetName = workbook.SheetNames[0];
        const sheetData = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1 });

        for (const row of sheetData)
		{
            const code = row[0];
            const num = row[1];
            const sender = row[2];
            const objectName = row[3];
            const observations = row[4];
            const methodNumber = row[5];
            const dateOfDispatch = row[6];
            const isOffer = code && code.startsWith('0');
            const mappedMethod = mapMethodOfDelivery(methodNumber);

            try
			{
                if (isOffer)
				{
                    await client_carrito.query(
													`SELECT create_received_documentation_offer(
																									$1,
																									$2,
																									$3,
																									$4,
																									$5,
																									$6,
																									$7,
																									$8,
																									$9
																								);`,
													[
														'migrador',
														'\\x0000000000000000000000000000000000000000000000000000000000000000',
														code,
														num,
														sender,
														objectName,
														observations,
														mappedMethod,
														dateOfDispatch
													]
											  );
                }
				else
				{
                    await client_carrito.query(
													`SELECT create_received_documentation_work(
														$1,
														$2,
														$3,
														$4,
														$5,
														$6,
														$7,
														$8,
														$9
													);`,
													[
														'migrador',
														'\\x0000000000000000000000000000000000000000000000000000000000000000',
														code,
														num,
														sender,
														objectName,
														observations,
														mappedMethod,
														dateOfDispatch
													]
											  );
                }
            }
			catch (err)
			{
                console.error(`Error inserting row with code ${code} and num ${num}:`, err.message);
            }
        }
        console.log('Received documents migrated successfully!');
    }
	catch (err)
	{
        console.error('Error during migration:', err.message);
    }
	finally
	{
        if (client_carrito)
		{
            await client_carrito.end();
        }
    }
}

async function migrate_sent_docs(ip, username, password, dbName)
{
    let client_carrito;

    try
	{
        client_carrito = new Client(
										{
								            host: ip,
								            user: username,
								            password: password,
								            database: dbName
										}
									);

        await client_carrito.connect();

        const workbook = XLSX.readFile('docEmitidaCarrito_cleaned.XLS');
        const sheetName = workbook.SheetNames[0];
        const sheetData = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1 });

        for (const row of sheetData)
		{
            const code = row[0];
            const num = row[1];
            const recipient = row[2];
            const objectName = row[3];
            const observations = row[4];
            const methodNumber = row[5];
            const dateOfDispatch = row[6];
            const isOffer = code && code.startsWith('0');
            const mappedMethod = mapMethodOfDelivery(methodNumber);

            try
			{
                if (isOffer)
				{
                    await client_carrito.query(
													`SELECT create_sent_documentation_offer(
																								$1,
																								$2,
																								$3,
																								$4,
																								$5,
																								$6,
																								$7,
																								$8,
																								$9
																							);`,
													[
														'migrador',
														'\\x0000000000000000000000000000000000000000000000000000000000000000',
														code,
														num,
														recipient,
														objectName,
														observations,
														mappedMethod,
														dateOfDispatch
													]
											  );
                }
				else
				{
                    await client_carrito.query(
													`SELECT create_sent_documentation_work(
																								$1,
																								$2,
																								$3,
																								$4,
																								$5,
																								$6,
																								$7,
																								$8,
																								$9
																							);`,
													[
														'migrador',
														'\\x0000000000000000000000000000000000000000000000000000000000000000',
														code,
														num,
														recipient,
														objectName,
														observations,
														mappedMethod,
														dateOfDispatch
													]
											  );
                }
            }
			catch (err)
			{
                console.error(`Error inserting row with code ${code} and num ${num}:`, err.message);
            }
        }
        console.log('Sent documents migrated successfully!');
    }
	catch (err)
	{
        console.error('Error during migration:', err.message);
    }
	finally
	{
        if (client_carrito)
		{
            await client_carrito.end();
        }
    }
}

async function migrate_works(ip, username, password, dbName)
{
    let client_carrito;

    try
	{
        client_carrito = new Client(
										{
								            host: ip,
       									    user: username,
								            password: password,
								            database: dbName
       									}
									);

        await client_carrito.connect();

        const workbook = XLSX.readFile('Trabajos_cleaned.XLS');
        const sheetName = workbook.SheetNames[0];
        const sheetData = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1 });

        for (const row of sheetData)
		{
            const offer_code = row[0];
            const work_code = row[1];
            const title = row[2];
            const client_code = row[3];
            const constructor_code = row[4];
            const other_documents = row[5];
            const observations = row[6];
            const notes = row[7];

            try
			{
                await client_carrito.query(
						                        `SELECT create_work(
                                                                        $1,
                                                                        $2,
                                                                        $3,
                                                                        $4,
                                                                        $5,
                                                                        $6,
                                                                        $7,
                                                                        $8,
                                                                        $9,
                                                                        $10
                    		    									);`,
                                                [
                                                    'migrador',
                                                    '\\x0000000000000000000000000000000000000000000000000000000000000000',
                                                    offer_code,
                                                    work_code,
                                                    title,
                                                    client_code,
                                                    constructor_code,
                                                    other_documents,
                                                    observations,
                                                    notes
                                                ]
                							);
            }
			catch (err)
			{
                console.error(`Error inserting row with offer_code ${offer_code} and work_code ${work_code}:`, err.message);
            }
        }
        console.log('Works migrated successfully!');
    }
	catch (err)
	{
        console.error('Error during migration:', err.message);
    }
	finally
	{
        await client_carrito.end();
    }
}

async function migrate_offers(ip, username, password, dbName)
{
    let client_carrito;

    try
	{
        client_carrito = new Client(
										{
                                            host: ip,
                                            user: username,
                                            password: password,
                                            database: dbName // connect to "carrito"
        								}
									);

        await client_carrito.connect();

        const workbook = XLSX.readFile('Ofertas_cleaned.XLS');
        const sheetName = workbook.SheetNames[0];
        const sheetData = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1 });

        for (const row of sheetData)
		{
            const code = row[0];
            const title = row[1];
            const client_code = row[2];
            const location = row[3];
            const observations = row[4];
            const notes = row[5];

            try
			{
                await client_carrito.query(
                	                            `SELECT create_offer(
                	                                                    $1,
                 	                                                    $2,
                 	                                                    $3,
                 	                                                    $4,
                 	                                                    $5,
                 	                                                    $6,
                 	                                                    $7,
                 	                                                    $8
                                            				       	);`,
                                                [
                                                    'migrador',
                                                    '\\x0000000000000000000000000000000000000000000000000000000000000000',
                                                    code,
                                                    title,
                                                    client_code,
                                                    location,
                                                    observations,
                                                    notes
                                                ]
                                        	);
            }
			catch (err)
			{
                console.error(`Error inserting row with code ${code}:`, err.message);
            }
        }
        console.log('Offers migrated successfully!');
    }
	catch (err)
	{
        console.error('Error during migration:', err.message);
    }
	finally
	{
        await client_carrito.end();
    }
}

async function create_database(ip, username, password, dbName)
{
    let client_carrito;

    try
	{
        client_carrito = new Client(
										{
							                host: ip,
							                user: username,
							                password: password,
							                database: 'postgres' // Connect to postgres first to manage databases
							        	}
									);

        await client_carrito.connect();

        await client_carrito.query('DROP DATABASE IF EXISTS carrito');
        await client_carrito.query('DROP USER IF EXISTS gateway_role');
        await client_carrito.query('CREATE DATABASE carrito');
        await client_carrito.end();

        client_carrito = new Client(
										{
  								          host: ip,
  								          user: username,
  								          password: password,
  								          database: dbName
  								      	}
									);

        await client_carrito.connect();

        const createTables = await fs.readFile('create_tables.sql', 'utf8');

        try
		{
            await client_carrito.query(createTables);
            console.log('Database recreated and tables created successfully!');
        }
		catch (err)
		{
            console.error('Error executing SQL file:', err.message);
            throw err;
        }
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

async function main()
{
	await create_database('127.0.0.1', 'postgres', 'vD6jxIe8bgz2dDyAo4VH9G4t6u7qha', 'carrito');
	await migrate_offers('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
	await migrate_works('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
	await migrate_sent_docs('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
	await migrate_received_docs('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
}

main()