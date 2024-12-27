//document.getElementById('open-path').addEventListener
//(
//	'click',
//	(event) =>
//	{
//		event.preventDefault();
//		window.electronAPI.openPath();
//	}
//);
function dragHandler(event, startX, startWidth, dataColumn)
{
    const newWidth = startWidth + event.clientX - startX;

    dataColumn.style.width = newWidth + 'px';
}

function stopDrag(dragHandlerCaller)
{
    document.documentElement.removeEventListener('mousemove', dragHandlerCaller, false);
    document.documentElement.removeEventListener('mouseup', stopDrag, false);
}

function mouseDownHandler(event)
{
    const dataColumn = document.getElementById('data-column');
    const startX = event.clientX;
    const startWidth = parseInt(window.getComputedStyle(dataColumn).width, 10);
    const dragHandlerCaller = function(event) {dragHandler(event, startX, startWidth, dataColumn);};
    const stopDragCaller = function() {stopDrag(dragHandlerCaller);};

    document.documentElement.addEventListener('mousemove', dragHandlerCaller, false);
    document.documentElement.addEventListener('mouseup', stopDragCaller, false);
    event.preventDefault();
}

document.addEventListener('DOMContentLoaded', function(){document.getElementById('resize-grip').addEventListener('mousedown', mouseDownHandler);});

function display_data_in_column(data)
{
	const container = document.getElementById('data-column');

	if (Array.isArray(data) == false)
	{
		const errorDiv = document.createElement('div');
		errorDiv.textContent = data;
		container.appendChild(errorDiv);		
		return;
	}
	data.forEach
	(
		(row, index) =>
		{
			const rowDiv = document.createElement('div');
			rowDiv.classList.add('content-item'); 

			Object.keys(row).forEach
			(
				(key) =>
				{
					const item = document.createElement('div');
					item.textContent = `${row[key]}`;
					rowDiv.appendChild(item);
				}
			);
			rowDiv.addEventListener
			(
				'click', () =>
				{
					const mainContent = document.getElementById('main-content');
					const newElement = document.createElement('div');

					mainContent.innerHTML = ""; // Clear previous content
					newElement.textContent = `this is the element ${rowDiv.textContent}`;
					newElement.style.position = 'absolute';
					newElement.style.top = '50%';
					newElement.style.left = '50%';
					newElement.style.transform = 'translate(-50%, -50%)';
					newElement.style.backgroundColor = 'white';
					newElement.style.padding = '10px';
					newElement.style.border = '1px solid black';
					newElement.style.textAlign = 'center';
					mainContent.appendChild(newElement);
			});

			container.appendChild(rowDiv);
		}
	);
}

window.onload = async () =>
{
	try
	{
		const data = await window.electronAPI.getCodes();
		display_data_in_column(data);
	}
	catch (error)
	{
		console.error('Error fetching codes:', error);
	}
};

window.electronAPI.onLog((_, message) => {console.log(`Main process log: ${message}`);});

document.addEventListener('DOMContentLoaded', function () {
    const filterInput = document.getElementById('filter-input');
    const dataColumn = document.getElementById('data-column');
    const contentItems = dataColumn.getElementsByClassName('content-item');

    // Event listener for filtering content
    filterInput.addEventListener('input', function () {
        const filterValue = filterInput.value.toLowerCase(); // Get the typed input and convert to lowercase

        // Loop through each content item and filter based on the input
        for (let i = 0; i < contentItems.length; i++) {
            const itemText = contentItems[i].textContent.toLowerCase(); // Get the text of each item and convert to lowercase

            if (itemText.includes(filterValue)) {
                contentItems[i].style.display = ''; // Show the item if it matches the filter
            } else {
                contentItems[i].style.display = 'none'; // Hide the item if it doesn't match
            }
        }
    });
});
