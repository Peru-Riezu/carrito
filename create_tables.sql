CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for hashing user passwords
ALTER DATABASE carrito SET default_transaction_isolation TO 'serializable'; -- better safe than sorry

CREATE TABLE user_t
(
	name VARCHAR(10) PRIMARY KEY,
	password BYTEA NOT NULL,
	password_expiration_date DATE NOT NULL DEFAULT (current_date + interval '1 year'),
	is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
	is_admin BOOLEAN NOT NULL DEFAULT FALSE,
	email text,
	phone_number text,
	CONSTRAINT hash_length CHECK (octet_length(password) = 32)
);

INSERT INTO user_t (name, password, is_admin) VALUES 
('migrador', '\x0000000000000000000000000000000000000000000000000000000000000000', TRUE);

CREATE TABLE offer_t
(
	code CHAR(6) NOT NULL PRIMARY KEY,
	title TEXT NOT NULL,
	client_code INTEGER NOT NULL,
	place TEXT,
	observations TEXT,
	notes TEXT,
	is_read_only BOOLEAN NOT NULL DEFAULT FALSE,
	CONSTRAINT format CHECK  (code ~ '^[0][0-9]{5}$')
);

CREATE TABLE work_t
(
	offer_code CHAR(6) NOT NULL REFERENCES offer_t(code),
	code CHAR(6) NOT NULL PRIMARY KEY,
	title TEXT NOT NULL,
	client_code INTEGER NOT NULL,
	constructor_code INTEGER,
	other_documents TEXT,
	observations TEXT,
	notes TEXT,
	is_read_only BOOLEAN NOT NULL DEFAULT FALSE,
	CONSTRAINT format CHECK (code ~ '^[1-9][0-9]{5}$')
);

CREATE TYPE e_method_of_delivery AS ENUM ('email', 'cd', 'messenger', 'onhand', 'fax', 'ftp', 'other');

CREATE TABLE sent_documentation_offer_t
(
	associated_offer_code CHAR(6) NOT NULL REFERENCES offer_t(code),
	num INTEGER NOT NULL,
	recipient TEXT NOT NULL,
	object_name TEXT NOT NULL,
	observations TEXT,
	method_of_delivery e_method_of_delivery NOT NULL,
	date_of_dispatch DATE,
	PRIMARY KEY (num, associated_offer_code)
);

CREATE TABLE received_documentation_offer_t
(
	associated_offer_code CHAR(6) NOT NULL REFERENCES offer_t(code),
	num INTEGER NOT NULL,
	sender TEXT NOT NULL,
	object_name TEXT NOT NULL,
	observations TEXT,
	method_of_delivery e_method_of_delivery NOT NULL,
	date_of_dispatch DATE,
	PRIMARY KEY (num, associated_offer_code)
);

CREATE TABLE sent_documentation_work_t
(
	associated_work_code CHAR(6) NOT NULL REFERENCES work_t(code),
	num INTEGER NOT NULL,
	recipient TEXT NOT NULL,
	object_name TEXT NOT NULL,
	observations TEXT,
	method_of_delivery e_method_of_delivery NOT NULL,
	date_of_dispatch DATE,
	PRIMARY KEY (num, associated_work_code)
);

CREATE TABLE received_documentation_work_t
(
	associated_work_code CHAR(6) NOT NULL REFERENCES work_t(code),
	num INTEGER NOT NULL,
	sender TEXT NOT NULL,
	object_name TEXT NOT NULL,
	observations TEXT,
	method_of_delivery e_method_of_delivery NOT NULL,
	date_of_dispatch DATE,
	PRIMARY KEY (num, associated_work_code)
);

CREATE TABLE received_work_documentation_file_t
(
	associated_work_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size BIGINT NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_work_code, file_name),
	FOREIGN KEY (num, associated_work_code) REFERENCES received_documentation_work_t(num, associated_work_code)
);

CREATE TABLE sent_work_documentation_file_t
(
	associated_work_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size BIGINT NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_work_code, file_name),
	FOREIGN KEY (num, associated_work_code) REFERENCES sent_documentation_work_t(num, associated_work_code)
);

CREATE TABLE received_offer_documentation_file_t
(
	associated_offer_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size BIGINT NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_offer_code, file_name),
	FOREIGN KEY (num, associated_offer_code) REFERENCES received_documentation_offer_t(num, associated_offer_code)
);

CREATE TABLE sent_offer_documentation_file_t
(
	associated_offer_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size BIGINT NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_offer_code, file_name),
	FOREIGN KEY (num, associated_offer_code) REFERENCES sent_documentation_offer_t(num, associated_offer_code)
);

CREATE TYPE e_action AS ENUM
(
	'create_offer', -- done
	'create_sent_documentation_offer', -- done
	'create_sent_offer_documentation_file', -- done
	'create_received_documentation_offer', -- done
	'create_received_documentation_offer_file', -- done
	'delete_offer', -- done
	'delete_sent_documentation_offer', -- done
	'delete_sent_offer_documentation_file', -- done
	'delete_received_documentation_offer', -- done
	'delete_received_documentation_offer_file', -- done
	'archive_offer', -- done
	'reopen_offer', -- done
	'create_work', -- done
	'create_sent_documentation_work', -- done
	'create_sent_work_documentation_file', -- done
	'create_received_documentation_work', -- done
	'create_received_documentation_work_file', -- done
	'delete_work', -- done
	'delete_sent_documentation_work', -- done
	'delete_sent_work_documentation_file', -- done
	'delete_received_documentation_work', -- done
	'delete_received_documentation_work_file', -- done
	'archive_work', -- done
	'reopen_work', -- done
	'create_user', -- done
	'update_user_phone_number', -- done
	'update_user_email', --done
	'delete_user', --done
	'block_user', --done
	'unblock_user', --done
	'set_new_user_password', --done
	'set_user_password_to_expired', --done
	'update_work_observations', --done
	'update_work_notes', --done
	'update_offer_observations', --done
	'update_offer_notes' --done
);

--this is to log the actions, all functions will add an entry here before modifyng the other tables
CREATE TABLE action_t
(
	action e_action NOT NULL,
	username VARCHAR(10) NOT NULL,
	time_of_action TIMESTAMP NOT NULL DEFAULT NOW(),
	targets_name VARCHAR(10),
	offer_code CHAR(6),
	work_code CHAR(6),
	num INTEGER,
	recipient_or_sender TEXT,
	object_name TEXT,
	observations TEXT,
	method_of_delivery e_method_of_delivery,
	date_of_dispatch DATE,
	file_size BIGINT,
	file_name TEXT,
	content BYTEA,
	email text,
	phone_number text,
	title TEXT,
	client_code INTEGER,
	place TEXT,
	notes TEXT,
	constructor_code INTEGER,
	other_documents TEXT
);

CREATE OR REPLACE FUNCTION validate_user(username VARCHAR(10), user_password BYTEA)
RETURNS BOOLEAN AS
$$
	BEGIN
		IF NOT EXISTS (SELECT TRUE FROM user_t WHERE name = username AND password = user_password)
		THEN
			RAISE EXCEPTION 'Invalid username or password';
	    END IF;

		IF EXISTS(SELECT TRUE FROM user_t WHERE name = username AND password_expiration_date < CURRENT_DATE)
		THEN
		   RAISE EXCEPTION 'Password expired';
		END IF;

		IF EXISTS(SELECT TRUE FROM user_t WHERE name = username AND is_blocked = TRUE)
		THEN
			RAISE EXCEPTION 'User is blocked';
		END IF;

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION check_if_admin(username VARCHAR(10))
RETURNS BOOLEAN AS
$$
	BEGIN
	   IF NOT EXISTS (
						SELECT true
						FROM user_t
						WHERE name = username AND is_admin = TRUE
					)
		THEN
			RAISE EXCEPTION 'User does not have permission to perform this action';
		END IF;

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION create_offer(
											username VARCHAR(10),
											user_password BYTEA,
											code CHAR(6),
											title TEXT,
											client_code INTEGER,
											place TEXT,
											observations TEXT,
											notes TEXT
										)
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		INSERT INTO offer_t(code, title, client_code, place, observations, notes)
		VALUES(code, title, client_code, place, observations, notes);

		INSERT INTO action_t(action, username, offer_code, title, client_code, place, observations, notes)
		VALUES('create_offer', username, code, title, client_code, place, observations, notes);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION delete_offer(username VARCHAR(10), user_password BYTEA, targets_code CHAR(6))
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		DELETE FROM offer_t WHERE code = targets_code;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No offer exists with that code';
		END IF;

		INSERT INTO action_t(action, username, offer_code)
		VALUES('delete_offer', username, targets_code);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION archive_offer(username VARCHAR(10), user_password BYTEA, targets_code CHAR(6))
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF NOT EXISTS (SELECT TRUE FROM offer_t WHERE code = targets_code)
		THEN
			RAISE EXCEPTION 'No offer exists with the specified code';
		END IF;

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = targets_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is already archived.';
		END IF;

		UPDATE offer_t
		SET is_read_only = TRUE
		WHERE code = targets_code;

		INSERT INTO action_t(action, username, offer_code)
		VALUES('archive_offer', username, targets_code);

		RETURN TRUE;
	END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reopen_offer(username VARCHAR(10), user_password BYTEA, targets_code CHAR(6))
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF NOT EXISTS (SELECT 1 FROM offer_t WHERE code = targets_code) THEN
			RAISE EXCEPTION 'No offer exists with the specified code: %', targets_code;
		END IF;

		IF NOT EXISTS (SELECT 1 FROM offer_t WHERE code = targets_code AND is_read_only = FALSE) THEN
			RAISE EXCEPTION 'Offer is not archived.';
		END IF;

		UPDATE offer_t
		SET is_read_only = FALSE
		WHERE code = targets_code;

		INSERT INTO action_t(action, username, offer_code)
		VALUES('reopen_offer', username, targets_code);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_work(
											username VARCHAR(10),
											user_password BYTEA,
											offer_code CHAR(6),
											code CHAR(6),
											title TEXT,
											client_code INTEGER, 
											constructor_code INTEGER,
											other_documents TEXT,
											observations TEXT,
											notes TEXT
										)
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		INSERT INTO work_t (offer_code, code, title, client_code, constructor_code, other_documents, observations, notes)
		VALUES (offer_code, code, title, client_code, constructor_code, other_documents, observations, notes);

		INSERT INTO action_t(
								action,
								username,
								offer_code,
								work_code,
								title,
								client_code,
								constructor_code,
								other_documents,
								observations,
								notes
							)
		VALUES(
					'create_work',
					username,
					offer_code,
					code,
					title,
					client_code,
					constructor_code,
					other_documents,
					observations,
					notes
				);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION delete_work(username VARCHAR(10), user_password BYTEA, targets_code CHAR(6))
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		DELETE FROM work_t WHERE code = targets_code;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No work exists with that code';
		END IF;

		INSERT INTO action_t(action, username, work_code)
		VALUES('delete_work', username, targets_code);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION archive_work(username VARCHAR(10), user_password BYTEA, targets_code CHAR(6))
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF NOT EXISTS (SELECT TRUE FROM work_t WHERE code = targets_code)
		THEN
			RAISE EXCEPTION 'No work exists with the specified code';
		END IF;

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = targets_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is already archived.';
		END IF;

		UPDATE work_t
		SET is_read_only = TRUE
		WHERE code = targets_code;

		INSERT INTO action_t(action, username, work_code)
		VALUES('archive_work', username, targets_code);

		RETURN TRUE;
	END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reopen_work(username VARCHAR(10), user_password BYTEA, targets_code CHAR(6))
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF NOT EXISTS (SELECT 1 FROM work_t WHERE code = targets_code) THEN
			RAISE EXCEPTION 'No work exists with the specified code';
		END IF;

		IF NOT EXISTS (SELECT 1 FROM work_t WHERE code = targets_code AND is_read_only = FALSE) THEN
			RAISE EXCEPTION 'Work is not archived.';
		END IF;

		UPDATE work_t
		SET is_read_only = FALSE
		WHERE code = targets_code;

		INSERT INTO action_t(action, username, work_code)
		VALUES('reopen_work', username, targets_code);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_sent_documentation_offer(
																username VARCHAR(10),
																user_password BYTEA,
																associated_offer_code CHAR(6),
																num INTEGER,
																recipient TEXT,
																object_name TEXT,
																observations TEXT,
																method_of_delivery e_method_of_delivery,
																date_of_dispatch DATE
															)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		INSERT INTO sent_documentation_offer_t
			(associated_offer_code, num, recipient, object_name, observations, method_of_delivery, date_of_dispatch)
		VALUES (associated_offer_code, num, recipient, object_name, observations, method_of_delivery, date_of_dispatch);

		INSERT INTO action_t(
								action,
								username,
								offer_code,
								num,
								recipient_or_sender,
								object_name,
								observations,
								method_of_delivery,
								date_of_dispatch
							)
		VALUES(
					'create_sent_documentation_offer',
					username,
					associated_offer_code,
					num,
					recipient,
					object_name,
					observations,
					method_of_delivery,
					date_of_dispatch
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_received_documentation_offer(
																	username VARCHAR(10),
																	user_password BYTEA,
																	associated_offer_code CHAR(6),
																	num INTEGER,
																	sender TEXT,
																	object_name TEXT,
																	observations TEXT,
																	method_of_delivery e_method_of_delivery,
																	date_of_dispatch DATE
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		INSERT INTO received_documentation_offer_t
			(associated_offer_code, num, sender, object_name, observations, method_of_delivery, date_of_dispatch)
		VALUES(associated_offer_code, num, sender, object_name, observations, method_of_delivery, date_of_dispatch);

		INSERT INTO action_t(
								action,
								username,
								offer_code,
								num,
								recipient_or_sender,
								object_name,
								observations,
								method_of_delivery,
								date_of_dispatch
							)
		VALUES(
					'create_received_documentation_offer',
					username,
					associated_offer_code,
					num,
					sender,
					object_name,
					observations,
					method_of_delivery,
					date_of_dispatch
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_sent_documentation_work(
																username VARCHAR(10),
																user_password BYTEA,
																associated_work_code CHAR(6),
																num INTEGER,
																recipient TEXT,
																object_name TEXT,
																observations TEXT,
																method_of_delivery e_method_of_delivery,
																date_of_dispatch DATE
															)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		INSERT INTO sent_documentation_work_t
			(associated_work_code, num, recipient, object_name, observations, method_of_delivery, date_of_dispatch)
		VALUES(associated_work_code, num, recipient, object_name, observations, method_of_delivery, date_of_dispatch);

		INSERT INTO action_t(
								action,
								username,
								work_code,
								num,
								recipient_or_sender,
								object_name,
								observations,
								method_of_delivery,
								date_of_dispatch
							)
		VALUES(
					'create_sent_documentation_work',
					username,
					associated_work_code,
					num,
					recipient,
					object_name,
					observations,
					method_of_delivery,
					date_of_dispatch
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_received_documentation_work(
																	username VARCHAR(10),
																	user_password BYTEA,
																	associated_work_code CHAR(6),
																	num INTEGER,
																	sender TEXT,
																	object_name TEXT,
																	observations TEXT,
																	method_of_delivery e_method_of_delivery,
																	date_of_dispatch DATE
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		INSERT INTO received_documentation_work_t
			(associated_work_code, num, sender, object_name, observations, method_of_delivery, date_of_dispatch)
		VALUES(associated_work_code, num, sender, object_name, observations, method_of_delivery, date_of_dispatch);

		INSERT INTO action_t(
								action,
								username,
								work_code,
								num,
								recipient_or_sender,
								object_name,
								observations,
								method_of_delivery,
								date_of_dispatch
							)
		VALUES(
					'create_received_documentation_work',
					username,
					associated_work_code,
					num,
					sender,
					object_name,
					observations,
					method_of_delivery,
					date_of_dispatch
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_sent_documentation_offer(
																username VARCHAR(10),
																user_password BYTEA,
																targets_associated_offer_code CHAR(6),
																targets_num INTEGER
															)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = targets_associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		DELETE FROM sent_documentation_offer_t
			WHERE associated_offer_code = targets_associated_offer_code AND num = targets_num;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No sent documentation exists with that identifier';
		END IF;

		INSERT INTO action_t(action, username, offer_code, num)
		VALUES('delete_sent_documentation_offer', username, targets_associated_offer_code, targets_num);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_received_documentation_offer(
																	username VARCHAR(10),
																	user_password BYTEA,
																	targets_associated_offer_code CHAR(6),
																	targets_num INTEGER
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = targets_associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		DELETE FROM received_documentation_offer_t
			WHERE associated_offer_code = targets_associated_offer_code AND num = targets_num;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No received documentation exists with that identifier';
		END IF;

		INSERT INTO action_t(action, username, offer_code, num)
		VALUES('delete_received_documentation_offer', username, targets_associated_offer_code, targets_num);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_sent_documentation_work(
																username VARCHAR(10),
																user_password BYTEA,
																targets_associated_work_code CHAR(6),
																targets_num INTEGER
															)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = targets_associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		DELETE FROM sent_documentation_work_t
			WHERE associated_work_code = targets_associated_work_code AND num = targets_num;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No sent documentation exists with that identifier';
		END IF;

		INSERT INTO action_t(action, username, work_code, num)
		VALUES('delete_sent_documentation_work', username, targets_associated_work_code, targets_num);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_received_documentation_work(
																	username VARCHAR(10),
																	user_password BYTEA,
																	targets_associated_work_code CHAR(6),
																	targets_num INTEGER
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = targets_associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		DELETE FROM received_documentation_work_t
			WHERE associated_work_code = targets_associated_work_code AND num = targets_num;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No received documentation exists with that identifier';
		END IF;

		INSERT INTO action_t(action, username, work_code, num)
		VALUES('delete_received_documentation_work', username, targets_associated_work_code, targets_num);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_sent_offer_documentation_file(
																	username VARCHAR(10),
																	user_password BYTEA,
																	associated_offer_code CHAR(6),
																	num INTEGER,
																	file_size BIGINT,
																	file_name TEXT,
																	content BYTEA
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		INSERT INTO sent_offer_documentation_file_t(associated_offer_code, num, file_size, file_name, content)
		VALUES(associated_offer_code, num, file_size, file_name, content);

		INSERT INTO action_t(action, username, offer_code, num, file_size, file_name, content)
		VALUES(
					'create_sent_offer_documentation_file',
					username,
					associated_offer_code,
					num,
					file_size,
					file_name,
					content
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;
	
CREATE OR REPLACE FUNCTION create_received_documentation_offer_file(
																		username VARCHAR(10),
																		user_password BYTEA,
																		associated_offer_code CHAR(6),
																		num INTEGER,
																		file_size BIGINT,
																		file_name TEXT,
																		content BYTEA
																	)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM offer_t WHERE code = associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		INSERT INTO received_offer_documentation_file_t (associated_offer_code, num, file_size, file_name, content)
		VALUES (associated_offer_code, num, file_size, file_name, content);

		INSERT INTO action_t(action, username, offer_code, num, file_size, file_name, content)
		VALUES(
					'create_received_documentation_offer_file',
					username,
					associated_offer_code,
					num,
					file_size,
					file_name,
					content
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_sent_offer_documentation_file(
																	username VARCHAR(10),
																	user_password BYTEA,
																	targets_associated_offer_code CHAR(6),
																	targets_num INTEGER,
																	targets_file_name TEXT
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM offer_t WHERE code = targets_associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		DELETE FROM sent_offer_documentation_file_t
		WHERE associated_offer_code = targets_associated_offer_code
			AND num = targets_num
			AND file_name = targets_file_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No file was found with that identifier.';
		END IF;

		INSERT INTO action_t(action, username, offer_code, num, file_name)
		VALUES(
				'delete_sent_offer_documentation_file',
					username,
					targets_associated_offer_code,
					targets_num,
					targets_file_name
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_received_documentation_offer_file(
																		username VARCHAR(10),
																		user_password BYTEA,
																		targets_associated_offer_code CHAR(6),
																		targets_num INTEGER,
																		targets_file_name TEXT
																	)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM offer_t WHERE code = targets_associated_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived.';
		END IF;

		DELETE FROM received_offer_documentation_file_t
		WHERE associated_offer_code = targets_associated_offer_code
			AND num = targets_num
			AND file_name = targets_file_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No file found with that identifier.';
		END IF;

		INSERT INTO action_t(action, username, offer_code, num, file_name)
		VALUES(
					'delete_received_documentation_offer_file',
					username,
					targets_associated_offer_code,
					targets_num,
					targets_file_name
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_sent_work_documentation_file(
																	username VARCHAR(10),
																	user_password BYTEA,
																	associated_work_code CHAR(6),
																	num INTEGER,
																	file_size BIGINT,
																	file_name TEXT,
																	content BYTEA
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM work_t WHERE code = associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		INSERT INTO sent_work_documentation_file_t(associated_work_code, num, file_size, file_name, content)
		VALUES(associated_work_code, num, file_size, file_name, content);

		INSERT INTO action_t(action, username, work_code, num, file_size, file_name, content)
		VALUES(
					'create_sent_work_documentation_file',
					username,
					associated_work_code,
					num,
					file_size,
					file_name,
					content
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_received_documentation_work_file(
																		username VARCHAR(10),
																		user_password BYTEA,
																		associated_work_code CHAR(6),
																		num INTEGER,
																		file_size BIGINT,
																		file_name TEXT,
																		content BYTEA
																	)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM work_t WHERE code = associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		INSERT INTO received_work_documentation_file_t(associated_work_code, num, file_size, file_name, content)
		VALUES(associated_work_code, num, file_size, file_name, content);

		INSERT INTO action_t(action, username, work_code, num, file_size, file_name, content)
		VALUES(
					'create_received_documentation_work_file',
					username,
					associated_work_code,
					num,
					file_size,
					file_name,
					content
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_sent_work_documentation_file(
																	username VARCHAR(10),
																	user_password BYTEA,
																	targets_associated_work_code CHAR(6),
																	targets_num INTEGER,
																	targets_file_name TEXT
																)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM work_t WHERE code = targets_associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		DELETE FROM sent_work_documentation_file_t
		WHERE associated_work_code = targets_associated_work_code
			AND num = targets_num
			AND file_name = targets_file_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No file found with the specified identifier.';
		END IF;

		INSERT INTO action_t(action, username, work_code, num, file_name)
		VALUES(
					'delete_sent_work_documentation_file',
					username,
					targets_associated_work_code,
					targets_num,
					targets_file_name
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_received_documentation_work_file(
																		username VARCHAR(10),
																		user_password BYTEA,
																		targets_associated_work_code CHAR(6),
																		targets_num INTEGER,
																		targets_file_name TEXT
																	)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		IF EXISTS (SELECT 1 FROM work_t WHERE code = targets_associated_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived.';
		END IF;

		DELETE FROM received_work_documentation_file_t
		WHERE associated_work_code = targets_associated_work_code
			AND num = targets_num
			AND file_name = targets_file_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No file found with the specified identifier.';
		END IF;

		INSERT INTO action_t(action, username, work_code, num, file_name)
		VALUES(
					'delete_received_documentation_work_file',
					username,
					targets_associated_work_code,
					targets_num,
					targets_file_name
				);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_user(
											username VARCHAR(10),
											user_password BYTEA,
											targets_name VARCHAR(10),
											targets_password VARCHAR(256),
											targets_is_blocked BOOLEAN,
											targets_email text,
											targets_phone_number text
										)
RETURN BOOLEAN AS
$$
	DECLARE
		hashed_password BYTEA; 
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		hashed_password := digest(targets_name || targets_password, 'sha256');

		INSERT INTO user_t(name, password, is_blocked, email, phone_number)
		VALUES(targets_name, hashed_password, targets_is_blocked, targets_email, targets_phone_number);

		INSERT INTO action_t(action, username, targets_name, email, phone_number)
		VALUES('create_user', username, targets_name, targets_email, targets_phone_number);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_user_phone_number(
														username VARCHAR(10),
														user_password BYTEA,
														targets_name VARCHAR(10),
														new_phone_number TEXT
													)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		UPDATE user_t
		SET phone_number = new_phone_number
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username.';
		END IF;

		INSERT INTO action_t(action, username, targets_name, phone_number)
		VALUES('update_user_phone_number', username, targets_name, new_phone_number);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_user_email(
												username VARCHAR(10),
												user_password BYTEA,
												targets_name VARCHAR(10),
												new_email TEXT
											)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		UPDATE user_t
		SET email = new_email
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username.';
		END IF;

		INSERT INTO action_t(action, username, targets_name, email)
		VALUES('update_user_email', username, targets_name, new_email);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_user(username VARCHAR(10), user_password BYTEA, targets_name VARCHAR(10))
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		DELETE FROM user_t
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username.';
		END IF;

		INSERT INTO action_t(action, username, targets_name)
		VALUES('delete_user', username, targets_name);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION block_user(username VARCHAR(10), user_password BYTEA, targets_name VARCHAR(10))
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF EXISTS (SELECT TRUE FROM user_t WHERE name = targets_name AND is_blocked = TRUE)
		THEN
			RAISE EXCEPTION 'User % is already blocked.', targets_name;
		END IF;

		UPDATE user_t
		SET is_blocked = TRUE
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username.';
		END IF;

		INSERT INTO action_t(action, username, targets_name)
		VALUES('block_user', username, targets_name);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unblock_user(username VARCHAR(10), user_password BYTEA, targets_name VARCHAR(10))
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF EXISTS (SELECT TRUE FROM user_t WHERE name = targets_name AND is_blocked = FALSE)
		THEN
			RAISE EXCEPTION 'User % is not blocked.', targets_name;
		END IF;

		UPDATE user_t
		SET is_blocked = FALSE
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username.';
		END IF;

		INSERT INTO action_t(action, username, targets_name)
		VALUES('unblock_user', username, targets_name);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION set_new_user_password(
													username VARCHAR(10),
													user_password BYTEA,
													targets_name VARCHAR(10),
													new_password VARCHAR(256)
												)
RETURN BOOLEAN AS
$$
	DECLARE
	    hashed_password BYTEA;
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		hashed_password := digest(targets_name || new_password, 'sha256');

		UPDATE user_t
		SET password = hashed_password,
			password_expiration_date = CURRENT_DATE + INTERVAL '1 year'
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username';
		END IF;

		INSERT INTO action_t(action, username, targets_name)
		VALUES('set_new_user_password', username, targets_name);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION set_user_password_to_expired(
															username VARCHAR(10),
															user_password BYTEA,
															targets_name VARCHAR(10)
														)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		UPDATE user_t
		SET password_expiration_date = '0001-01-01'::DATE
		WHERE name = targets_name;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No user exists with the specified username';
		END IF;

		INSERT INTO action_t(action, username, targets_name)
		VALUES ('set_user_password_to_expired', username, targets_name);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_work_observations(
														username VARCHAR(10),
														user_password BYTEA,
														target_work_code CHAR(6),
														new_observations TEXT
													)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = target_work_code AND is_read_only = TRUE) THEN
			RAISE EXCEPTION 'Work is archived and cannot be modified.';
		END IF;

		UPDATE work_t
		SET observations = new_observations
		WHERE code = target_work_code;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No work exists with the specified code.';
		END IF;

		INSERT INTO action_t(action, username, work_code, observations)
		VALUES( 'update_work_observations', username, target_work_code, new_observations);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_work_notes(
												username VARCHAR(10),
												user_password BYTEA,
												target_work_code CHAR(6),
												new_notes TEXT
											)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF EXISTS (SELECT TRUE FROM work_t WHERE code = target_work_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Work is archived and cannot be modified.';
		END IF;

		UPDATE work_t
		SET notes = new_notes
		WHERE code = target_work_code;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No work exists with the specified code.';
		END IF;

		INSERT INTO action_t(action, username, work_code, notes)
		VALUES('update_work_notes', username, target_work_code, new_notes);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_offer_observations(
														username VARCHAR(10),
														user_password BYTEA,
														target_offer_code CHAR(6),
														new_observations TEXT
													)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = target_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived and cannot be modified.';
		END IF;

		UPDATE offer_t
		SET observations = new_observations
		WHERE code = target_offer_code;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No offer exists with the specified code.';
		END IF;

		INSERT INTO action_t(action, username, offer_code, observations)
		VALUES('update_offer_observations', username, target_offer_code, new_observations);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_offer_notes(
													username VARCHAR(10),
													user_password BYTEA,
													target_offer_code CHAR(6),
													new_notes TEXT
												)
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		IF EXISTS (SELECT TRUE FROM offer_t WHERE code = target_offer_code AND is_read_only = TRUE)
		THEN
			RAISE EXCEPTION 'Offer is archived and cannot be modified.';
		END IF;

		UPDATE offer_t
		SET notes = new_notes
		WHERE code = target_offer_code;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No offer exists with the specified code.';
		END IF;

		INSERT INTO action_t(action, username, offer_code, notes)
		VALUES('update_offer_notes', username, target_offer_code, new_notes);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_users(username VARCHAR(10), user_password BYTEA)
RETURNS SETOF user_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY SELECT * FROM user_t ORDER BY name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_data(username VARCHAR(10), user_password BYTEA, target_name VARCHAR(10))
RETURNS SETOF user_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY SELECT * FROM user_t WHERE name = target_name ORDER BY name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_offers(username VARCHAR(10), user_password BYTEA)
RETURNS SETOF offer_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY SELECT * FROM offer_t ORDER BY code;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION get_works(username VARCHAR(10), user_password BYTEA)
RETURNS SETOF work_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY SELECT * FROM work_t ORDER BY code;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_sent_documentation_offer(username VARCHAR(10), user_password BYTEA, offer_code CHAR(6))
RETURNS SETOF sent_documentation_offer_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY SELECT * FROM sent_documentation_offer_t WHERE associated_offer_code = offer_code ORDER BY num;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_sent_documentation_work(username VARCHAR(10), user_password BYTEA, work_code CHAR(6))
RETURNS SETOF sent_documentation_work_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY SELECT * FROM sent_documentation_work_t WHERE associated_work_code = work_code ORDER BY num;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_sent_documentation_files_offer(
																	username VARCHAR(10),
																	user_password BYTEA,
																	offer_code CHAR(6),
																	doc_num INTEGER
																)
RETURNS TABLE(associated_offer_code CHAR(6), num INTEGER, file_size BIGINT, file_name TEXT) AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT associated_offer_code, num, file_size, file_name
		FROM sent_offer_documentation_file_t
		WHERE associated_offer_code = offer_code
		  AND num = doc_num
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_sent_documentation_file_offer(
																username VARCHAR(10),
																user_password BYTEA,
																offer_code CHAR(6),
																doc_num INTEGER,
																file_name TEXT
															)
RETURNS SETOF sent_offer_documentation_file_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT *
		FROM sent_offer_documentation_file_t
		WHERE associated_offer_code = offer_code
		  AND num = doc_num
		  AND file_name = file_name
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_sent_documentation_files_work(
																username VARCHAR(10),
																user_password BYTEA,
																work_code CHAR(6),
																doc_num INTEGER
															)
RETURNS TABLE(associated_work_code CHAR(6), num INTEGER, file_size BIGINT, file_name TEXT) AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT associated_work_code, num, file_size, file_name
		FROM sent_work_documentation_file_t
		WHERE associated_work_code = work_code
		  AND num = doc_num
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_sent_documentation_file_work(
																username VARCHAR(10),
																user_password BYTEA,
																work_code CHAR(6),
																doc_num INTEGER,
																file_name TEXT
															)
RETURNS SETOF sent_work_documentation_file_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT *
		FROM sent_work_documentation_file_t
		WHERE associated_work_code = work_code
		  AND num = doc_num
		  AND file_name = file_name
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_received_documentation_offer(
																username VARCHAR(10),
																user_password BYTEA,
																offer_code CHAR(6)
															)
RETURNS SETOF received_documentation_offer_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT *
		FROM received_documentation_offer_t
		WHERE associated_offer_code = offer_code
		ORDER BY num;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_received_documentation_files_offer(
    username      VARCHAR(10),
    user_password BYTEA,
    offer_code    CHAR(6),
    doc_num       INTEGER
)
RETURNS TABLE(associated_offer_code CHAR(6), num INTEGER, file_size BIGINT, file_name TEXT) AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT associated_offer_code, num, file_size, file_name
		FROM received_offer_documentation_file_t
		WHERE associated_offer_code = offer_code
		  AND num = doc_num
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_received_documentation_file_offer(
																	username VARCHAR(10),
																	user_password BYTEA,
																	offer_code CHAR(6),
																	doc_num INTEGER,
																	file_name TEXT
																)
RETURNS SETOF received_offer_documentation_file_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT *
		FROM received_offer_documentation_file_t
		WHERE associated_offer_code = offer_code
		  AND num = doc_num
		  AND file_name = file_name
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_received_documentation_work(
																username VARCHAR(10),
																user_password BYTEA,
																work_code CHAR(6)
															)
RETURNS SETOF received_documentation_work_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT *
		FROM received_documentation_work_t
		WHERE associated_work_code = work_code
		ORDER BY num;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_received_documentation_files_work(
																	username VARCHAR(10),
																	user_password BYTEA,
																	work_code CHAR(6),
																	doc_num INTEGER
																)
RETURNS TABLE(associated_work_code CHAR(6), num INTEGER, file_size BIGINT, file_name TEXT) AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT associated_work_code, num, file_size, file_name
		FROM received_work_documentation_file_t
		WHERE associated_work_code = work_code
		  AND num = doc_num
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_received_documentation_file_work(
																	username VARCHAR(10),
																	user_password BYTEA,
																	work_code CHAR(6),
																	doc_num INTEGER,
																	file_name TEXT
																)
RETURNS SETOF received_work_documentation_file_t AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);

		RETURN QUERY
		SELECT *
		FROM received_work_documentation_file_t
		WHERE associated_work_code = work_code
		  AND num = doc_num
		  AND file_name = file_name
		ORDER BY file_name;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE ROLE gateway_role LOGIN PASSWORD 'exnz2tg54gm7qkkj4e4nj';
GRANT EXECUTE ON FUNCTION create_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION archive_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION reopen_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION create_work TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_work TO gateway_role;
GRANT EXECUTE ON FUNCTION archive_work TO gateway_role;
GRANT EXECUTE ON FUNCTION reopen_work TO gateway_role;
GRANT EXECUTE ON FUNCTION create_sent_documentation_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION create_received_documentation_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION create_sent_documentation_work TO gateway_role;
GRANT EXECUTE ON FUNCTION create_received_documentation_work TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_sent_documentation_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_received_documentation_offer TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_sent_documentation_work TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_received_documentation_work TO gateway_role;
GRANT EXECUTE ON FUNCTION create_sent_offer_documentation_file TO gateway_role;
GRANT EXECUTE ON FUNCTION create_received_documentation_offer_file TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_sent_offer_documentation_file TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_received_documentation_offer_file TO gateway_role;
GRANT EXECUTE ON FUNCTION create_sent_work_documentation_file TO gateway_role;
GRANT EXECUTE ON FUNCTION create_received_documentation_work_file TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_sent_work_documentation_file TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_received_documentation_work_file TO gateway_role;
GRANT EXECUTE ON FUNCTION create_user TO gateway_role;
GRANT EXECUTE ON FUNCTION update_user_phone_number TO gateway_role;
GRANT EXECUTE ON FUNCTION update_user_email TO gateway_role;
GRANT EXECUTE ON FUNCTION delete_user TO gateway_role;
GRANT EXECUTE ON FUNCTION block_user TO gateway_role;
GRANT EXECUTE ON FUNCTION unblock_user TO gateway_role;
GRANT EXECUTE ON FUNCTION set_new_user_password TO gateway_role;
GRANT EXECUTE ON FUNCTION set_user_password_to_expired TO gateway_role;
GRANT EXECUTE ON FUNCTION update_work_observations TO gateway_role;
GRANT EXECUTE ON FUNCTION update_work_notes TO gateway_role;
GRANT EXECUTE ON FUNCTION update_offer_observations TO gateway_role;
GRANT EXECUTE ON FUNCTION update_offer_notes TO gateway_role;

GRANT EXECUTE ON FUNCTION get_offers(VARCHAR(10), BYTEA)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_works(VARCHAR(10), BYTEA)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_users(VARCHAR(10), BYTEA)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_user_data(VARCHAR(10), BYTEA, VARCHAR(10))
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_sent_documentation_offer(VARCHAR(10), BYTEA, CHAR(6))
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_sent_documentation_work(VARCHAR(10), BYTEA, CHAR(6))
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_sent_documentation_files_offer(VARCHAR(10), BYTEA, CHAR(6), INTEGER)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_sent_documentation_file_offer(VARCHAR(10), BYTEA, CHAR(6), INTEGER, TEXT)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_sent_documentation_files_work(VARCHAR(10), BYTEA, CHAR(6), INTEGER)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_sent_documentation_file_work(VARCHAR(10), BYTEA, CHAR(6), INTEGER, TEXT)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_received_documentation_offer(VARCHAR(10), BYTEA, CHAR(6))
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_received_documentation_files_offer(VARCHAR(10), BYTEA, CHAR(6), INTEGER)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_received_documentation_file_offer(VARCHAR(10), BYTEA, CHAR(6), INTEGER, TEXT)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_received_documentation_work(VARCHAR(10), BYTEA, CHAR(6))
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_received_documentation_files_work(VARCHAR(10), BYTEA, CHAR(6), INTEGER)
TO gateway_role;
GRANT EXECUTE ON FUNCTION get_received_documentation_file_work(VARCHAR(10), BYTEA, CHAR(6), INTEGER, TEXT)
TO gateway_role;
