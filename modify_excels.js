const XLSX = require('xlsx');
const path = require('path');
const fs = require('fs');
const readlineSync = require('readline-sync');

let ofertas_no_migradas = 0;
let ofertas_migradas = 0;
const seen_offers = new Map();

let trabajos_no_migrados= 0;
let trabajos_migrados = 0;
const seen_works = new Map();

let documentacion_emitida_no_migrada = 0;
let documentacion_emitida_migrada = 0;

let documentacion_recibida_no_migrada = 0;
let documentacion_recibida_migrada = 0;


function waitForKeypress()
{
	process.stdin.setRawMode(true);
	process.stdin.resume();
	let buf = Buffer.alloc(1);

	fs.readSync(0, buf, 0, 1);
	if (buf[0] === 0x0D)
	{
		fs.readSync(0, buf, 0, 1); // read and discard the '\n'
	}
	process.stdin.setRawMode(false);
	process.stdin.pause();
}

function get_path_to_archived(windowsPath)
{
	const regex = /^G:\\trabajos\\(\d{6})\\(.+)$/;
	const match = windowsPath.match(regex);
	if (!match)
	{
		return "";
	}
	const sixDigitCode = match[1];
	const restOfPath = match[2];
	const twoDigitYear = parseInt(sixDigitCode.substring(2, 4), 10);
	const fullYear = twoDigitYear <= 25 ? 2000 + twoDigitYear : 1900 + twoDigitYear;
	const newPath = `B:\\${fullYear}\\${sixDigitCode}\\${restOfPath}`;

	return newPath;
}

function get_file_paths(filePath)
{
	try
	{
		const stats = fs.statSync(filePath);

		if (stats.isFile())
		{
			try
			{
				fs.accessSync(filePath, fs.constants.R_OK);
				return filePath; // File exists and is readable
			}
			catch
			{
				return null; // File is not readable
			}
		}
		if (stats.isDirectory())
		{
			try
			{
				const files = fs.readdirSync(filePath);
				const readableFiles = files.filter
				(
					(file) =>
					{
						const fullPath = path.join(filePath, file);
						try
						{
							fs.accessSync(fullPath, fs.constants.R_OK);
							return fs.statSync(fullPath).isFile(); // Ensure it's a readable file
						}
						catch
						{
							return false; // Skip unreadable or non-file entries
						}
					}
				);
				return readableFiles.length > 0 ? readableFiles.map((file) => path.join(filePath, file)) : null;
			}
			catch
			{
				return null; // Directory cannot be read or does not exist
			}
		}
		return null; // Path is neither a file nor a directory
	}
	catch
	{
		return null; // Path does not exist
	}
}

function clean_Ofertas(inputFile)
{
	if (!fs.existsSync(inputFile))
	{
		console.error('Input file does not exist.');
		return;
	}

	const ext = path.extname(inputFile);
	if (ext.toLowerCase() !== '.xls' && ext.toLowerCase() !== '.xlsx') {
		console.error('Unsupported file format. Only .xls or .xlsx files are supported.');
		return;
	}

	const workbook = XLSX.readFile(inputFile);
	const sheetName = workbook.SheetNames[0];
	if (!sheetName)
	{
		console.error('No sheets found in the file.');
		return;
	}

	const sheet = workbook.Sheets[sheetName];
	let data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

	data.shift();

	const columnsToRemove = [0, 2, 3, 6, 8, 9, 10, 11, 14];
	const maxColumns = Math.max(...data.map(row => row.length));
	data = data.map
	(
		row =>
		{
			return Array.from({ length: maxColumns }, (_, index) => row[index] ?? null);
		}
	);
	
	data = data.map(row => row.filter((_, index) => !columnsToRemove.includes(index)));
	
	data = data.filter((row, i) =>
	{
		if (/^07/.test(row[0]))
		{
			return false;
		}

		if (!/^\d{6}$/.test(row[0]))
		{
			console.error(`Fila ${i + 2} de la tabla Ofertas no puede ser migrada porque el codigo de oferta no esta compuesto de seis digitos.`);
			ofertas_no_migradas++;
			return false;
		}

		if (!row[1])
		{
			console.error(`Fila ${i + 2} de la tabla Ofertas no puede ser migrada porque la columna de titulo está vacía.`);
			ofertas_no_migradas++;
			return false;
		}

		if (!row[2])
		{
			console.error(`Fila ${i + 2} de la tabla Ofertas no puede ser migrada porque la columna de cliente está vacía.`);
			ofertas_no_migradas++;
			return false;
		}

		seen_offers.set(row[0], null);
		ofertas_migradas++;
		return true;
	});

	const newSheet = XLSX.utils.aoa_to_sheet(data);
	const newWorkbook = XLSX.utils.book_new();
	XLSX.utils.book_append_sheet(newWorkbook, newSheet, sheetName);

	const base = path.basename(inputFile, ext);
	const outputFile = `${base}_cleaned${ext}`;
	XLSX.writeFile(newWorkbook, outputFile);
}

function clean_Trabajos(inputFile)
{
	if (!fs.existsSync(inputFile))
	{
		console.error('Input file does not exist.');
		return;
	}

	const ext = path.extname(inputFile);
	if (ext.toLowerCase() !== '.xls' && ext.toLowerCase() !== '.xlsx') {
		console.error('Unsupported file format. Only .xls or .xlsx files are supported.');
		return;
	}

	const workbook = XLSX.readFile(inputFile);
	const sheetName = workbook.SheetNames[0];
	if (!sheetName)
	{
		console.error('No sheets found in the file.');
		return;
	}

	const sheet = workbook.Sheets[sheetName];
	let data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

	data.shift();

	const columnsToRemove = [0, 3, 4, 7, 8, 10, 11, 12, 13, 14];
	const maxColumns = Math.max(...data.map(row => row.length));
	data = data.map
	(
		row =>
		{
			return Array.from({ length: maxColumns }, (_, index) => row[index] ?? null);
		}
	);
	
	data = data.map(row => row.filter((_, index) => !columnsToRemove.includes(index)));
	
	data = data.filter((row, i) =>
	{
		if (/^07/.test(row[0]) || /^70/.test(row[1]))
		{
			return false;
		}

		if (seen_offers.has(row[0]) == false)
		{
			console.error(`Fila ${i + 2} de la tabla Trabajos no puede ser migrada porque el codigo de oferta asociado no es valido.`);
			trabajos_no_migrados++;
			return false;
		}

		if (!/^\d{6}$/.test(row[1]))
		{
			console.error(`Fila ${i + 2} de la tabla Trabajos no puede ser migrada porque el codigo de trabajo no esta compuesto de seis digitos.`);
			trabajos_no_migrados++;
			return false;
		}
		
		if (row[0] == row[1])
		{
			console.error(`Fila ${i + 2} de la tabla Trabajos no puede ser migrada porque el codigo de trabajo es el codigo de oferta.`);
			trabajos_no_migrados++;
			return false;
		}

		if (!row[2])
		{
			console.error(`Fila ${i + 2} de la tabla Trabajos no puede ser migrada porque la columna de titulo está vacía.`);
			trabajos_no_migrados++;
			return false;
		}

		if (!row[3])
		{
			console.error(`Fila ${i + 2} de la tabla Trabajos no puede ser migrada porque la columna de cliente está vacía.`);
			trabajos_no_migrados++;
			return false;
		}

		seen_works.set(row[1], null);
		trabajos_migrados++;
		return true;
	});

	const newSheet = XLSX.utils.aoa_to_sheet(data);
	const newWorkbook = XLSX.utils.book_new();
	XLSX.utils.book_append_sheet(newWorkbook, newSheet, sheetName);

	const base = path.basename(inputFile, ext);
	const outputFile = `${base}_cleaned${ext}`;
	XLSX.writeFile(newWorkbook, outputFile);
}

function clean_docEmitida(inputFile)
{
	if (!fs.existsSync(inputFile))
	{
		console.error('Input file does not exist.');
		return;
	}
	const ext = path.extname(inputFile);
	if (ext.toLowerCase() !== '.xls' && ext.toLowerCase() !== '.xlsx') {
		console.error('Unsupported file format. Only .xls or .xlsx files are supported.');
		return;
	}
	const workbook = XLSX.readFile(inputFile);
	const sheetName = workbook.SheetNames[0];
	if (!sheetName) {
		console.error('No sheets found in the file.');
		return;
	}
	const sheet = workbook.Sheets[sheetName];
	let data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

	data.shift();

	const seenCombinations = new Set();
	data = data.filter((row, i) =>
	{
		if (seen_offers.has(row[0]) == false && seen_works.has(row[0]) == false)
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque el codigo de oferta o trabajo asociado no es correcto.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		const combination = `${row[0]}|${row[1]}`;
		if (seenCombinations.has(combination))
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque la combinación de la primera y segunda columna no es única.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		if (!row[2])
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque la columna de destinatario está vacía.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		if (!row[3])
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque la columna de objeto está vacía.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		if (!row[5])
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque la columna de modo está vacía.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		if (!row[6])
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque la columna de fecha está vacía.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		const date = new Date(Math.round((row[6] - 25569) * 864e5));
		row[6] = date.toLocaleDateString('en-GB');
		if (!row[7])
		{
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque la columna de archivado está vacía.`);
			documentacion_emitida_no_migrada++;
			return false;
		}
		let files = get_file_paths(row[7]);
		if (files == null)
		{
			const new_path = get_path_to_archived(row[7]);
			if (new_path == "")
			{
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque no hay archivos en la dirección especificada.`);
				documentacion_emitida_no_migrada++;
				return false;
			}
			files = get_file_paths(new_path);
			if (files == null)
			{
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque no hay archivos en la dirección especificada.`);
				documentacion_emitida_no_migrada++;
				return false;
			}
			if (seen_offers.has(row[0]))
			{
				if (seen_offers.get(row[0]) == null)
				{
					seen_offers.set(row[0], 'archived');
				}
				else if (seen_offers.get(row[0]) == 'non_archived')
				{
					console.error(`\n\n\n\nAtencion!! La oferta ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
					console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando la oferta asociada desde G: y el archivo se encuentra en B:.\n\n\n`);
					waitForKeypress();
					documentacion_emitida_no_migrada++;
					return false;
				}
				if (Array.isArray(files))
				{
					row[7] = files.join('|');
				}
				else
				{
					row[7] = files;
				}
				seenCombinations.add(combination);
				documentacion_emitida_migrada++;
				return true;
			}
			if (seen_works.get(row[0]) == null)
			{
				seen_offers.set(row[0], 'archived');
			}
			else if (seen_works.get(row[0]) == 'non_archived')
			{
				console.error(`\n\n\n\nAtencion!! El trabajo ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando el trabajo asociado desde G: y el archivo se encuentra en B:.\n\n\n`);
				waitForKeypress();
				documentacion_emitida_no_migrada++;
				return false;
			}
			if (Array.isArray(files))
			{
				row[7] = files.join('|');
			}
			else
			{
				row[7] = files;
			}
			seenCombinations.add(combination);
			documentacion_emitida_migrada++;
			return true;
		}
		if (seen_offers.has(row[0]))
		{
			if (seen_offers.get(row[0]) == null)
			{
				seen_offers.set(row[0], 'non_archived');
			}
			else if (seen_offers.get(row[0]) == 'archived')
			{
				console.error(`\n\n\n\nAtencion!! La oferta ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando la oferta asociada desde B: y el archivo se encuentra en G:.\n\n\n`);
				waitForKeypress();
				documentacion_emitida_no_migrada++;
				return false;
			}
			if (Array.isArray(files))
			{
				row[7] = files.join('|');
			}
			else
			{
				row[7] = files;
			}
			seenCombinations.add(combination);
			documentacion_emitida_migrada++;
			return true;
		}
		if (seen_works.get(row[0]) == null)
		{
			seen_offers.set(row[0], 'non_archived');
		}
		else if (seen_works.get(row[0]) == 'archived')
		{
			console.error(`\n\n\n\nAtencion!! El trabajo ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando el trabajo asociado desde B: y el archivo se encuentra en G:.\n\n\n`);
			waitForKeypress();
			documentacion_emitida_no_migrada++;
			return false;
		}
		if (Array.isArray(files))
		{
			row[7] = files.join('|');
		}
		else
		{
			row[7] = files;
		}
		seenCombinations.add(combination);
		documentacion_emitida_migrada++;
		return true;
	});
	const newSheet = XLSX.utils.aoa_to_sheet(data);
	const newWorkbook = XLSX.utils.book_new();
	XLSX.utils.book_append_sheet(newWorkbook, newSheet, sheetName);
	const base = path.basename(inputFile, ext);
	const outputFile = `${base}_cleaned${ext}`;
	XLSX.writeFile(newWorkbook, outputFile);
}

function clean_docRecibida(inputFile)
{
	if (!fs.existsSync(inputFile))
	{
		console.error('Input file does not exist.');
		return;
	}
	const ext = path.extname(inputFile);
	if (ext.toLowerCase() !== '.xls' && ext.toLowerCase() !== '.xlsx') {
		console.error('Unsupported file format. Only .xls or .xlsx files are supported.');
		return;
	}
	const workbook = XLSX.readFile(inputFile);
	const sheetName = workbook.SheetNames[0];
	if (!sheetName) {
		console.error('No sheets found in the file.');
		return;
	}
	const sheet = workbook.Sheets[sheetName];
	let data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

	data.shift();
	const seenCombinations = new Set();
	data = data.filter((row, i) =>
	{
		if (seen_offers.has(row[0]) == false && seen_works.has(row[0]) == false)
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque el codigo de oferta o trabajo asociado no es correcto.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		const combination = `${row[0]}|${row[1]}`;
		if (seenCombinations.has(combination))
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque la combinación de la primera y segunda columna no es única.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		if (!row[2])
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque la columna de destinatario está vacía.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		if (!row[3])
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque la columna de objeto está vacía.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		if (!row[5])
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque la columna de modo está vacía.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		if (!row[6])
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque la columna de fecha está vacía.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		const date = new Date(Math.round((row[6] - 25569) * 864e5));
		row[6] = date.toLocaleDateString('en-GB');
		if (!row[7])
		{
			console.error(`Fila ${i + 2} de la tabla docRecibidaCarrito no puede ser migrada porque la columna de archivado está vacía.`);
			documentacion_recibida_no_migrada++;
			return false;
		}
		let files = get_file_paths(row[7]);
		if (files == null)
		{
			const new_path = get_path_to_archived(row[7]);
			files = get_file_paths(new_path);
			if (files == null)
			{
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque no hay archivos en la dirección especificada.`);
				documentacion_recibida_no_migrada++;
				return false;
			}
			if (seen_offers.has(row[0]))
			{
				if (seen_offers.get(row[0]) == null)
				{
					seen_offers.set(row[0], 'archived');
				}
				else if (seen_offers.get(row[0]) == 'non_archived')
				{
					console.error(`\n\n\n\nAtencion!! La oferta ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
					console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando la oferta asociada desde G: y el archivo se encuentra en B:.\n\n\n`);
					waitForKeypress();
					documentacion_recibida_no_migrada++;
					return false;
				}
				if (Array.isArray(files))
				{
					row[7] = files.join('|');
				}
				else
				{
					row[7] = files;
				}
				seenCombinations.add(combination);
				documentacion_recibida_migrada++;
				return true;
			}
			if (seen_works.get(row[0]) == null)
			{
				seen_offers.set(row[0], 'archived');
			}
			else if (seen_works.get(row[0]) == 'non_archived')
			{
				console.error(`\n\n\n\nAtencion!! El trabajo ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando el trabajo asociado desde G: y el archivo se encuentra en B:.\n\n\n`);
				waitForKeypress();
				documentacion_recibida_no_migrada++;
				return false;
			}
			if (Array.isArray(files))
			{
				row[7] = files.join('|');
			}
			else
			{
				row[7] = files;
			}
			seenCombinations.add(combination);
			documentacion_recibida_migrada++;
			return true;
		}
		if (seen_offers.has(row[0]))
		{
			if (seen_offers.get(row[0]) == null)
			{
				seen_offers.set(row[0], 'non_archived');
			}
			else if (seen_offers.get(row[0]) == 'archived')
			{
				console.error(`\n\n\n\nAtencion!! La oferta ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
				console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando la oferta asociada desde B: y el archivo se encuentra en G:.\n\n\n`);
				waitForKeypress();
				documentacion_recibida_no_migrada++;
				return false;
			}
			if (Array.isArray(files))
			{
				row[7] = files.join('|');
			}
			else
			{
				row[7] = files;
			}
			seenCombinations.add(combination);
			documentacion_recibida_migrada++;
			return true;
		}
		if (seen_works.get(row[0]) == null)
		{
			seen_offers.set(row[0], 'non_archived');
		}
		else if (seen_works.get(row[0]) == 'archived')
		{
			console.error(`\n\n\n\nAtencion!! El trabajo ${row[0]} se encuentra sinmultanea e incompletamente en G: y B:.`);
			console.error(`Fila ${i + 2} de la tabla docEmitidaCarrito no puede ser migrada porque se esta migrando el trabajo asociado desde B: y el archivo se encuentra en G:.\n\n\n`);
			waitForKeypress();
			documentacion_recibida_no_migrada++;
			return false;
		}
		if (Array.isArray(files))
		{
			row[7] = files.join('|');
		}
		else
		{
			row[7] = files;
		}
		seenCombinations.add(combination);
		documentacion_recibida_migrada++;
		return true;
	});
	const newSheet = XLSX.utils.aoa_to_sheet(data);
	const newWorkbook = XLSX.utils.book_new();
	XLSX.utils.book_append_sheet(newWorkbook, newSheet, sheetName);
	const base = path.basename(inputFile, ext);
	const outputFile = `${base}_cleaned${ext}`;
	XLSX.writeFile(newWorkbook, outputFile);
}

clean_Ofertas("Ofertas.XLS");
clean_Trabajos("Trabajos.XLS");
clean_docEmitida('docEmitidaCarrito.XLS');
clean_docRecibida("docRecibidaCarrito.XLS");

console.warn(`Total de ofertas no migradas: ${ofertas_no_migradas}`);
console.info('\x1b[32m%s\x1b[0m', `Totatal de ofertas migradas: ${ofertas_migradas}`);
console.info('\x1b[32m%s\x1b[0m', `porcentaje de ofertas migradas: ${ofertas_migradas  / (ofertas_no_migradas + ofertas_migradas) * 100}%`);

console.warn(`Total de trabajos no migrados: ${trabajos_no_migrados}`);
console.info('\x1b[32m%s\x1b[0m', `Totatal de trabajos migrados: ${trabajos_migrados}`);
console.info('\x1b[32m%s\x1b[0m', `porcentaje de trabajos migrados: ${trabajos_migrados  / (trabajos_no_migrados + trabajos_migrados) * 100}%`);

console.warn(`Total de documentacion emitida no migrada: ${documentacion_emitida_no_migrada}`);
console.info('\x1b[32m%s\x1b[0m', `Total de documentacion emitida migrada: ${documentacion_emitida_migrada}`);
console.info('\x1b[32m%s\x1b[0m', `porcentaje de documentacion emitida migrada: ${documentacion_emitida_migrada  / (documentacion_emitida_no_migrada + documentacion_emitida_migrada) * 100}%`);

console.warn(`Total de documentacion recivida no migrada: ${documentacion_recibida_no_migrada}`);
console.info('\x1b[32m%s\x1b[0m', `Total de documentacion recibida migrada: ${documentacion_recibida_migrada}`);
console.info('\x1b[32m%s\x1b[0m', `porcentaje de documentacion recibida migrada: ${documentacion_recibida_migrada  / (documentacion_recibida_no_migrada + documentacion_recibida_migrada) * 100}%`);

console.info('\x1b[32m%s\x1b[0m', `porcentaje de documentacion recibida/emitida migrada: ${(documentacion_recibida_migrada + documentacion_emitida_migrada)  / (documentacion_recibida_no_migrada + documentacion_recibida_migrada + documentacion_emitida_migrada + documentacion_emitida_no_migrada) * 100}%`);