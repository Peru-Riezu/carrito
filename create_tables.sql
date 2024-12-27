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
	is_read_only BOOLEAN NOT NULL DEFAULT FALSE
	CHECK (code ~ '^[1-9][0-9]{5}$')
);

CREATE TYPE e_method_of_delivery AS ENUM ('email', 'cd', 'messenger', 'onhand', 'fax', 'ftp', 'other');

CREATE TABLE sent_documentation_offer_t
(
	associated_offer_code CHAR(6) NOT NULL REFERENCES offer_t(code),
	num INT NOT NULL,
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
	num INT NOT NULL,
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
	num INT NOT NULL,
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
	num INT NOT NULL,
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
	file_size INTEGER NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_work_code, file_name),
	FOREIGN KEY (num, associated_work_code) REFERENCES received_documentation_work_t(num, associated_work_code)
);

CREATE TABLE sent_work_documentation_file_t
(
	associated_work_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size INTEGER NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_work_code, file_name),
	FOREIGN KEY (num, associated_work_code) REFERENCES sent_documentation_work_t(num, associated_work_code)
);

CREATE TABLE received_offer_documentation_file_t
(
	associated_offer_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size INTEGER NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_offer_code, file_name),
	FOREIGN KEY (num, associated_offer_code) REFERENCES received_documentation_offer_t(num, associated_offer_code)
);

CREATE TABLE sent_offer_documentation_file_t
(
	associated_offer_code CHAR(6) NOT NULL,
	num INTEGER NOT NULL,
	file_size INTEGER NOT NULL,
	file_name TEXT NOT NULL,
	content BYTEA,
	PRIMARY KEY (num, associated_offer_code, file_name),
	FOREIGN KEY (num, associated_offer_code) REFERENCES sent_documentation_offer_t(num, associated_offer_code)
);

CREATE TYPE e_action AS ENUM
(
	'create_offer', -- done
	'create_sent_documentation_offer', -- in progress
	'create_sent_offer_documentation_file',
	'create_received_documentation_offer', -- in progress
	'create_received_documentation_offer_file',
	'delete_offer', --done
	'delete_sent_documentation_offer', -- in progress
	'delete_sent_offer_documentation_file',
	'delete_received_documentation_offer', --  in progress
	'delete_received_documentation_offer_file',
	'archive_offer', --done
	'reopen_offer', --done
	'create_work', --done
	'create_sent_documentation_work', -- in progress
	'create_sent_work_documentation_file',
	'create_received_documentation_work', -- in progress
	'create_received_documentation_work_file',
	'delete_work', --done
	'delete_sent_documentation_work', -- in progress
	'delete_sent_work_documentation_file',
	'delete_received_documentation_work', -- in progress
	'delete_received_documentation_work_file',
	'archive_work', --done
	'reopen_work', --done
	'create_user',
	'update_user_phone_number',
	'update_user_email',
	'delete_user',
	'block_user',
	'unblock_user',
	'set_new_user_password',
	'set_user_password_to_expiered'
);

-- getters that need to be programmed
-- get_offers
-- get_works
-- get_users
-- get_user_data(id)
-- get_sent_documentation_offer(offer_code)
-- get_sent_documentation_files_offer(offer_code, num)
-- get_sent_documentation_file_offer(offer_code, num, filename)
-- get_sent_documentation_work(work_code)
-- get_sent_documentation_files_work(work_code, num)
-- get_sent_documentation_file_work(work_code, num, filename)

--this is to log the actions, all functions will add an entry here before modifyng the other tables
CREATE TABLE action_t
(
	action e_action NOT NULL,
	username CHAR(10) NOT NULL,
	time_of_action TIMESTAMP NOT NULL DEFAULT NOW(),
	offer_code CHAR(6),
	work_code CHAR(6),
	num INTEGER,
	recipient_or_sender TEXT,
	object_name TEXT,
	observations TEXT,
	method_of_delivery e_method_of_delivery,
	date_of_dispatch DATE,
	file_size INTEGER,
	file_name TEXT,
	content BYTEA,
	email text,
	phone_number text,
	new_password BYTEA,
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
		IF NOT EXISTS (
						SELECT TRUE
						FROM user_t
						WHERE name = username AND password = user_password
					)
		THEN
			RAISE EXCEPTION 'Invalid username or password';
	    END IF;

		IF EXISTS(
					SELECT TRUE
					FROM user_t
					WHERE name = username AND password_expiration_date < CURRENT_DATE
				)
		THEN
		   RAISE EXCEPTION 'Password expired';
		END IF;

		IF EXISTS(
					SELECT TRUE
					FROM user_t
					WHERE name = username AND is_blocked = TRUE
				)
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

		INSERT INTO offer_t (code, title, client_code, place, observations, notes)
		VALUES (code, title, client_code, place, observations, notes);

		INSERT INTO action_t (action, username, offer_code, title, client_code, place, observations, notes)
		VALUES ('create_offer', username, code, title, client_code, place, observations, notes);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION delete_offer(
											username VARCHAR(10),
											user_password BYTEA,
											targets_code CHAR(6)
										)
RETURNS BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
		PERFORM check_if_admin(username);

		DELETE FROM offer_t WHERE code = targets_code;
		IF NOT FOUND
		THEN
			RAISE EXCEPTION 'No offer exists whit that code';
		END IF;

		INSERT INTO action_t (action, username, offer_code)
		VALUES ('delete_offer', username, targets_code);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION archive_offer(
											username VARCHAR(10),
											user_password BYTEA,
											targets_code CHAR(6)
										)
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

		INSERT INTO action_t (action, username, offer_code)
		VALUES ('archive_offer', username, targets_code);

		RETURN TRUE;
	END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reopen_offer(
											username VARCHAR(10),
											user_password BYTEA,
											targets_code CHAR(6)
										)
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

		INSERT INTO action_t (action, username, offer_code)
		VALUES ('reopen_offer', username, targets_code);

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

	    INSERT INTO action_t (action, username, offer_code, work_code, title, client_code, constructor_code, other_documents, observations, notes)
	    VALUES ('create_work',  username, offer_code, code, title, client_code, constructor_code, other_documents, observations, notes);

	    RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION delete_work(
											username VARCHAR(10),
											user_password BYTEA,
											targets_code CHAR(6)
										)
RETURNS BOOLEAN AS
$$
	BEGIN
	    PERFORM validate_user(username, user_password);
	    PERFORM check_if_admin(username);

		DELETE FROM work_t WHERE code = targets_code;
	    IF NOT FOUND
		THEN
	        RAISE EXCEPTION 'No work exists whit that code';
	    END IF;

	    INSERT INTO action_t (action, username, work_code)
	    VALUES ('delete_work', username, targets_code);

	    RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY definer;

CREATE OR REPLACE FUNCTION archive_work(
											username VARCHAR(10),
											user_password BYTEA,
											targets_code CHAR(6)
										)
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

		INSERT INTO action_t (action, username, work_code)
		VALUES ('archive_work', username, targets_code);

		RETURN TRUE;
	END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reopen_work(
											username VARCHAR(10),
											user_password BYTEA,
											targets_code CHAR(6)
										)
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

		INSERT INTO action_t (action, username, work_code)
		VALUES ('reopen_work', username, targets_code);

		RETURN TRUE;
	END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_sent_documentation_offer(
																username VARCHAR(10),
																user_password BYTEA,
															    associated_offer_code CHAR(6),
															    num INT,
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

		INSERT INTO action_t (action, username, work_code, num, recipient_or_sender, object_name, method_of_delivery, date_of_dispatch)
		VALUES ('create_sent_documentation_offer', username, associated_offer_code, num, recipient, object_name, method_of_delivery, date_of_dispatch);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_received_documentation_offer(
																username VARCHAR(10),
																user_password BYTEA,
															    associated_offer_code CHAR(6),
															    num INT,
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

		INSERT INTO action_t (action, username, work_code, num, recipient_or_sender, object_name, method_of_delivery, date_of_dispatch)
		VALUES ('create_received_documentation_offer', username, associated_offer_code, num, sender, object_name, method_of_delivery, date_of_dispatch);

		RETURN TRUE;
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_sent_documentation_work(
																username VARCHAR(10),
																user_password BYTEA,
															    associated_work_code CHAR(6),
															    num INT,
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
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_received_documentation_work()
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_sent_documentation_offer()
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_received_documentation_offer()
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_sent_documentation_work()
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
	END
$$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_received_documentation_work()
RETURN BOOLEAN AS
$$
	BEGIN
		PERFORM validate_user(username, user_password);
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
