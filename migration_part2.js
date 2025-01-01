const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

async function archive_if_needed(client_carrito, code, isOffer)
{
	try
	{
		if (isOffer)
		{
			await client_carrito.query(
				`SELECT archive_offer($1, $2, $3);`,
				[
					'migrador',
					'\\x0000000000000000000000000000000000000000000000000000000000000000',
					code
				]
			);
		}
		else
		{
			await client_carrito.query(
				`SELECT archive_work($1, $2, $3);`,
				[
					'migrador',
					'\\x0000000000000000000000000000000000000000000000000000000000000000',
					code
				]
			);
		}
	}
	catch (err)
	{
	}
}

async function archive_sent_files(ip, username, password, dbName)
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
			const filePaths = row[7];

			const firstPath = filePaths.split('|')[0].trim();
			const isArchived = firstPath.startsWith('B:');
			const isOffer = code.startsWith('0');

			if (isArchived)
			{
				await archive_if_needed(client_carrito, code, isOffer);
			}
		}
		console.log('Sent files archiving completed successfully!');
	}
	catch (err)
	{
	}
	finally
	{
		if (client_carrito)
		{
			await client_carrito.end();
		}
	}
}

async function archive_received_files(ip, username, password, dbName)
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
			const filePaths = row[7];

			const firstPath = filePaths.split('|')[0].trim();
			const isArchived = firstPath.startsWith('B:');
			const isOffer = code.startsWith('0');

			if (isArchived)
			{
				await archive_if_needed(client_carrito, code, isOffer);
			}
		}
		console.log('Received files archiving completed successfully!');
	}
	catch (err)
	{
	}
	finally
	{
		if (client_carrito)
		{
			await client_carrito.end();
		}
	}
}

function get_file_paths(filePath)
{
	try
	{
		const stats = fs.statSync(filePath);

		if (stats.isDirectory())
		{
			const files = fs.readdirSync(filePath);
			return files.map((file) => path.join(filePath, file)).filter((filePath) =>
			{
				try
				{
					fs.accessSync(filePath, fs.constants.R_OK);
					return fs.statSync(filePath).isFile();
				}
				catch
				{
					return false;
				}
			});
		}
		return null;
	}
	catch
	{
		return null;
	}
}

async function migrate_sent_files(ip, username, password, dbName)
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
			const filePaths = row[7];

			const firstPath = filePaths.split('|')[0].trim();
			const directoryPath = path.dirname(firstPath);
			const files = get_file_paths(directoryPath);

			if (!files)
			{
				console.error(`No files found in directory: ${directoryPath}`);
				continue;
			}

			const isOffer = code.startsWith('0');

			for (const filePath of files)
			{
				const fileName = path.basename(filePath);
				const fileSize = fs.statSync(filePath).size;
				const fileContent = fs.readFileSync(filePath);

				try
				{
					if (isOffer)
					{
						await client_carrito.query(
							`SELECT create_sent_offer_documentation_file(
																			$1,
																			$2,
																			$3,
																			$4,
																			$5,
																			$6,
																			$7
																		);`,
							[
								'migrador',
								'\\x0000000000000000000000000000000000000000000000000000000000000000',
								code,
								num,
								fileSize,
								fileName,
								fileContent
							]
						);
					}
					else
					{
						await client_carrito.query(
							`SELECT create_sent_work_documentation_file(
																			$1,
																			$2,
																			$3,
																			$4,
																			$5,
																			$6,
																			$7
																		);`,
							[
								'migrador',
								'\\x0000000000000000000000000000000000000000000000000000000000000000',
								code,
								num,
								fileSize,
								fileName,
								fileContent
							]
						);
					}
				}
				catch (err)
				{
					console.error(`Error inserting file ${fileName} for code ${code}:`, err.message);
				}
			}
		}
		console.log('Sent files migrated successfully!');
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

async function migrate_received_files(ip, username, password, dbName)
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
			if (row.length < 8)
			{
				console.warn('Skipping row due to insufficient columns:', row);
				continue;
			}

			const code = row[0];
			const num = row[1];
			const filePaths = row[7];

			if (!code || !num || !filePaths)
			{
				console.warn('Skipping row due to missing critical fields:', row);
				continue;
			}

			const firstPath = filePaths.split('|')[0].trim();
			const directoryPath = path.dirname(firstPath);
			const files = get_file_paths(directoryPath);

			if (!files)
			{
				console.error(`No files found in directory: ${directoryPath}`);
				continue;
			}

			const isOffer = code.startsWith('0');

			for (const filePath of files)
			{
				const fileName = path.basename(filePath);
				const fileSize = fs.statSync(filePath).size;
				const fileContent = fs.readFileSync(filePath);

				try
				{
					if (isOffer)
					{
						await client_carrito.query(
							`SELECT create_received_documentation_offer_file(
																				$1,
																				$2,
																				$3,
																				$4,
																				$5,
																				$6,
																				$7
																			);`,
							[
								'migrador',
								'\\x0000000000000000000000000000000000000000000000000000000000000000',
								code,
								num,
								fileSize,
								fileName,
								fileContent
							]
						);
					}
					else
					{
						await client_carrito.query(
							`SELECT create_received_documentation_work_file(
																				$1,
																				$2,
																				$3,
																				$4,
																				$5,
																				$6,
																				$7
																			);`,
							[
								'migrador',
								'\\x0000000000000000000000000000000000000000000000000000000000000000',
								code,
								num,
								fileSize,
								fileName,
								fileContent
							]
						);
					}
				}
				catch (err)
				{
					console.error(`Error inserting file ${fileName} for code ${code}:`, err.message);
				}
			}
		}
		console.log('Received files migrated successfully!');
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

async function main()
{
	await migrate_sent_files('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
	await migrate_received_files('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');

	await archive_sent_files('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
	await archive_received_files('127.0.0.1', 'gateway_role', 'exnz2tg54gm7qkkj4e4nj', 'carrito');
}

main()