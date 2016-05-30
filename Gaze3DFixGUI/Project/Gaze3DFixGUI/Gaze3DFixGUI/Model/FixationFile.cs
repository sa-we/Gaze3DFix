using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Gaze3DFixGUI.Model
{
    class FixationFile
    {
        public String filename = "";

        public List<FixationData> list_FixationData = new List<FixationData>();

        public FixationFile ()
        {

        }

        public void addFixationData(FixationData fixationdata)
        {
            list_FixationData.Add(fixationdata);
        }
    }
}
